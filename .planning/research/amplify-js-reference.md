# Amplify JS/UI Passkey Implementation Reference

**Researched:** 2026-03-07
**Overall confidence:** HIGH (verified from GitHub source code + official documentation)

## Executive Summary

Amplify JS (`@aws-amplify/auth` v6.15+) implements comprehensive passkey/WebAuthn support through a layered architecture: a platform-agnostic auth flow layer talks to Cognito, a passkey utilities layer handles WebAuthn API calls and serialization, and platform-specific implementations (web vs React Native) handle the actual credential ceremonies. Amplify UI's React Authenticator component integrates passkey flows via an XState-based state machine with dedicated states for challenge selection and passkey registration prompts.

This document serves as a reference for implementing equivalent functionality in amplify-flutter.

---

## 1. Architecture Overview

### Package Structure in amplify-js

```
packages/auth/src/
  client/
    apis/
      associateWebAuthnCredential.ts    # Registration API (post-auth)
      listWebAuthnCredentials.ts        # List credentials API
      deleteWebAuthnCredential.ts       # Delete credential API
    flows/
      userAuth/
        handleUserAuthFlow.ts           # USER_AUTH InitiateAuth flow
        handleSelectChallenge.ts        # SELECT_CHALLENGE response
        handleWebAuthnSignInResult.ts   # WEB_AUTHN challenge handler
        handleSelectChallengeWithPassword.ts
        handleSelectChallengeWithPasswordSRP.ts
    utils/
      passkey/
        getPasskey.ts                   # Web: navigator.credentials.get()
        getPasskey.native.ts            # RN: delegates to rtn-passkeys
        registerPasskey.ts              # Web: navigator.credentials.create()
        registerPasskey.native.ts       # RN: delegates to rtn-passkeys
        getIsPasskeySupported.ts        # Web: feature detection
        getIsPasskeySupported.native.ts # RN: feature detection
        serde.ts                        # Base64url <-> ArrayBuffer conversion
        types/
          index.ts                      # Type guards & assertions
          shared.ts                     # JSON serialization types
        errors/
          passkeyError.ts               # Error codes & PasskeyError class

packages/rtn-passkeys/                  # React Native Turbo Module
  src/
    NativeAmplifyRtnPasskeys.ts         # Native module interface
    index.ts
  android/                              # Android Credential Manager bridge
  ios/                                  # iOS ASAuthorization bridge
```

### Key Design Decisions

1. **Platform abstraction via file extension:** `.ts` for web, `.native.ts` for React Native. Build tools select the right file at compile time.
2. **Serialization layer:** All WebAuthn data goes through explicit serde functions that convert between JSON (base64url strings) and platform types (ArrayBuffer).
3. **Error wrapping:** All platform errors are caught and re-thrown as typed `PasskeyError` with specific error codes.
4. **Cognito API separation:** Registration uses token-authorized APIs (`StartWebAuthnRegistration`/`CompleteWebAuthnRegistration`). Sign-in uses `InitiateAuth`/`RespondToAuthChallenge` with `USER_AUTH` flow.

---

## 2. Public API Surface

### Exported Functions (from `@aws-amplify/auth`)

```typescript
// Sign-in with passkey (via signIn + confirmSignIn)
signIn({
  username: string,
  options: {
    authFlowType: 'USER_AUTH',
    preferredChallenge: 'WEB_AUTHN'  // optional
  }
}): Promise<SignInOutput>

confirmSignIn({
  challengeResponse: 'WEB_AUTHN' | 'EMAIL_OTP' | 'SMS_OTP' | 'PASSWORD' | 'PASSWORD_SRP'
}): Promise<SignInOutput>

// Credential management (requires authenticated user)
associateWebAuthnCredential(): Promise<void>
listWebAuthnCredentials(input?: ListWebAuthnCredentialsInput): Promise<ListWebAuthnCredentialsOutput>
deleteWebAuthnCredential(input: DeleteWebAuthnCredentialInput): Promise<void>
```

### Exported Types

```typescript
type AuthWebAuthnCredential = {
  credentialId: string;
  friendlyCredentialName: string;
  relyingPartyId: string;
  authenticatorAttachment: string;
  authenticatorTransports: string[];
  createdAt: number;
}

type DeleteWebAuthnCredentialInput = { credentialId: string }
type ListWebAuthnCredentialsInput = { pageSize?: number; nextToken?: string }
type ListWebAuthnCredentialsOutput = {
  credentials: AuthWebAuthnCredential[];
  nextToken?: string;
}
```

### SignIn NextStep Values for Passkey Flows

| `nextStep.signInStep` | Meaning | Action Required |
|---|---|---|
| `CONTINUE_SIGN_IN_WITH_FIRST_FACTOR_SELECTION` | Multiple auth methods available | Show selection UI, call `confirmSignIn({ challengeResponse: selectedMethod })` |
| `DONE` | Sign-in complete (passkey ceremony succeeded) | Navigate to authenticated state |

**Key behavior:** When `WEB_AUTHN` is selected (either via `preferredChallenge` or `confirmSignIn`), Amplify Auth **automatically** triggers the WebAuthn ceremony on the device. The developer does NOT manually call `navigator.credentials.get()`. If the ceremony succeeds, `nextStep` is `DONE`. If it fails, an error is thrown.

---

## 3. Sign-In Flow Implementation Details

### handleUserAuthFlow.ts

This function initiates the `USER_AUTH` flow with Cognito:

1. **Validates configuration:** Checks that the preferred challenge (if specified) is enabled in the auth config:
   - `EMAIL_OTP` -> checks `emailOtpEnabled`
   - `SMS_OTP` -> checks `smsOtpEnabled`
   - `WEB_AUTHN` -> checks `webAuthn` config exists
   - `PASSWORD` / `PASSWORD_SRP` -> checks password config
2. **Calls InitiateAuth:** Sends `AuthFlow: USER_AUTH` with optional `PREFERRED_CHALLENGE` parameter
3. **Stores username:** Sets the active sign-in username for subsequent challenge responses

### handleSelectChallenge.ts

When `SELECT_CHALLENGE` is returned from Cognito (no preferred challenge or preferred unavailable):

```typescript
// Generic function - passes selected challenge as ANSWER
respondToAuthChallenge({
  ChallengeName: 'SELECT_CHALLENGE',
  ChallengeResponses: {
    USERNAME: username,
    ANSWER: selectedChallenge,  // e.g., 'WEB_AUTHN'
  },
  ClientId: config.userPoolClientId,
  Session: session,
  ClientMetadata: clientMetadata,
});
```

**Important:** This function is generic -- it does NOT handle the WebAuthn ceremony itself. It just tells Cognito which challenge the user selected. Cognito then responds with the actual `WEB_AUTHN` challenge (including `CREDENTIAL_REQUEST_OPTIONS`), which is handled by `handleWebAuthnSignInResult`.

This confirms the SELECT_CHALLENGE + WEB_AUTHN flow is **two-step** in amplify-js:
1. Respond to SELECT_CHALLENGE with `ANSWER: "WEB_AUTHN"`
2. Receive WEB_AUTHN challenge with CREDENTIAL_REQUEST_OPTIONS
3. Perform ceremony and respond with CREDENTIAL

### handleWebAuthnSignInResult.ts (124 lines)

The core WebAuthn sign-in handler:

```typescript
async function handleWebAuthnSignInResult(challengeParameters) {
  // 1. Validate current challenge is WEB_AUTHN and username exists
  // 2. Extract CREDENTIAL_REQUEST_OPTIONS from challenge parameters
  const credentialRequestOptions = challengeParameters.CREDENTIAL_REQUEST_OPTIONS;

  // 3. Call platform WebAuthn API (browser or native)
  const credential = await getPasskey(JSON.parse(credentialRequestOptions));

  // 4. Send credential to Cognito
  const response = await respondToAuthChallenge({
    ChallengeName: 'WEB_AUTHN',
    ChallengeResponses: {
      USERNAME: username,
      CREDENTIAL: JSON.stringify(credential),  // serialized assertion
    },
    ClientId: config.userPoolClientId,
    Session: session,
  });

  // 5. Check result - sequential WEB_AUTHN challenges are not supported
  if (response.ChallengeName === 'WEB_AUTHN') {
    throw new Error('Sequential WEB_AUTHN challenges cannot be handled');
  }

  // 6. Return tokens or next challenge (e.g., MFA)
}
```

**Key insight:** The handler explicitly blocks sequential WEB_AUTHN challenges -- if Cognito returns another WEB_AUTHN after the first one, it throws an error. This is a defensive measure.

---

## 4. Registration Flow Implementation

### associateWebAuthnCredential.ts

Three-phase registration (user must be authenticated):

```typescript
async function associateWebAuthnCredential(): Promise<void> {
  // Phase 1: Get registration options from Cognito
  const { CredentialCreationOptions } = await startWebAuthnRegistration({
    AccessToken: tokens.accessToken.toString(),
  });

  assertValidCredentialCreationOptions(CredentialCreationOptions);

  // Phase 2: Create credential on device (browser or native)
  const credential = await registerPasskey(CredentialCreationOptions);

  // Phase 3: Complete registration with Cognito
  await completeWebAuthnRegistration({
    AccessToken: tokens.accessToken.toString(),
    Credential: credential,
  });
}
```

**No parameters needed** -- the function gets the access token from the current session automatically. This is a significant API design choice: the developer just calls `associateWebAuthnCredential()` and the entire flow runs.

---

## 5. WebAuthn Browser API Integration

### getPasskey.ts (Web - Authentication/Sign-in)

```typescript
export const getPasskey = async (input: PasskeyGetOptionsJson) => {
  try {
    // Check platform support
    const isPasskeySupported = getIsPasskeySupported();
    assertPasskeyError(isPasskeySupported, PasskeyErrorCode.PasskeyNotSupported);

    // Deserialize JSON options to WebAuthn types (base64url -> ArrayBuffer)
    const passkeyGetOptions = deserializeJsonToPkcGetOptions(input);

    // Call browser WebAuthn API
    const credential = await navigator.credentials.get({
      publicKey: passkeyGetOptions,
    });

    // Validate result type
    assertCredentialIsPkcWithAuthenticatorAssertionResponse(credential);

    // Serialize back to JSON (ArrayBuffer -> base64url)
    return serializePkcWithAssertionToJson(credential);
  } catch (err: unknown) {
    throw handlePasskeyAuthenticationError(err);
  }
};
```

### registerPasskey.ts (Web - Registration)

```typescript
export const registerPasskey = async (input: PasskeyCreateOptionsJson) => {
  try {
    const isPasskeySupported = getIsPasskeySupported();
    assertPasskeyError(isPasskeySupported, PasskeyErrorCode.PasskeyNotSupported);

    const passkeyCreationOptions = deserializeJsonToPkcCreationOptions(input);

    const credential = await navigator.credentials.create({
      publicKey: passkeyCreationOptions,
    });

    assertCredentialIsPkcWithAuthenticatorAttestationResponse(credential);

    return serializePkcWithAttestationToJson(credential);
  } catch (err: unknown) {
    throw handlePasskeyRegistrationError(err);
  }
};
```

### getIsPasskeySupported.ts (Web)

```typescript
export const getIsPasskeySupported = (): boolean => {
  return (
    isBrowser() &&
    window.isSecureContext &&
    'credentials' in navigator &&
    typeof window.PublicKeyCredential === 'function'
  );
};
```

Four-check validation: browser context, secure context (HTTPS), credentials API present, PublicKeyCredential constructor available.

### Native Implementations (.native.ts)

Both `getPasskey.native.ts` and `registerPasskey.native.ts` delegate to `@aws-amplify/react-native`:

```typescript
// getPasskey.native.ts
export const getPasskey = async (input: PasskeyGetOptionsJson) => {
  try {
    return await loadAmplifyRtnPasskeys().getPasskey(input);
  } catch (err: unknown) {
    throw handlePasskeyAuthenticationError(err);
  }
};

// registerPasskey.native.ts
export const registerPasskey = async (input: PasskeyCreateOptionsJson) => {
  try {
    return await loadAmplifyRtnPasskeys().createPasskey(input);
  } catch (err: unknown) {
    throw handlePasskeyRegistrationError(err);
  }
};
```

The `rtn-passkeys` package is a React Native Turbo Module with:
- **Android:** Uses Android Credential Manager API
- **iOS:** Uses `ASAuthorizationPlatformPublicKeyCredentialProvider`

---

## 6. Serialization Layer (serde.ts)

Four key functions handle conversion between JSON (what Cognito sends/expects) and WebAuthn platform types:

### Deserialization (JSON -> Platform)

**`deserializeJsonToPkcCreationOptions`** (for registration):
- Converts `user.id` from base64url string to ArrayBuffer
- Converts `challenge` from base64url string to ArrayBuffer
- Converts `excludeCredentials[].id` from base64url string to ArrayBuffer
- Result: `PublicKeyCredentialCreationOptions` ready for `navigator.credentials.create()`

**`deserializeJsonToPkcGetOptions`** (for authentication):
- Converts `challenge` from base64url string to ArrayBuffer
- Converts `allowCredentials[].id` from base64url string to ArrayBuffer
- Result: `PublicKeyCredentialRequestOptions` ready for `navigator.credentials.get()`

### Serialization (Platform -> JSON)

**`serializePkcWithAttestationToJson`** (registration result):
- Encodes `response.clientDataJSON` -> base64url string
- Encodes `response.attestationObject` -> base64url string
- Encodes `response.authenticatorData` -> base64url string (optional)
- Encodes `response.publicKey` -> base64url string (optional)
- Preserves `response.transports` and `response.publicKeyAlgorithm` as-is
- Preserves `clientExtensionResults` and `authenticatorAttachment`

**`serializePkcWithAssertionToJson`** (authentication result):
- Encodes `response.clientDataJSON` -> base64url string
- Encodes `response.authenticatorData` -> base64url string
- Encodes `response.signature` -> base64url string
- Encodes `response.userHandle` -> base64url string (optional)
- Preserves `clientExtensionResults` and `authenticatorAttachment`

### Helper Functions
- `convertArrayBufferToBase64Url(buffer: ArrayBuffer): string`
- `convertBase64UrlToArrayBuffer(base64url: string): ArrayBuffer`

### JSON Type Definitions (types/shared.ts)

```typescript
// Registration options (from Cognito)
interface PasskeyCreateOptionsJson {
  challenge: string;          // base64url
  rp: { id: string; name: string };
  user: { id: string; name: string; displayName: string };  // id is base64url
  pubKeyCredParams: Array<{ type: string; alg: number }>;
  timeout?: number;
  excludeCredentials?: Array<{ id: string; type: string; transports?: string[] }>;
  authenticatorSelection?: { ... };
  attestation?: string;
  extensions?: Record<string, unknown>;
}

// Registration result (to Cognito)
interface PasskeyCreateResultJson {
  id: string;
  rawId: string;              // base64url
  type: string;               // "public-key"
  clientExtensionResults: Record<string, unknown>;
  authenticatorAttachment?: string;
  response: PkcAttestationResponse<string>;  // all fields base64url strings
}

// Authentication options (from Cognito)
interface PasskeyGetOptionsJson {
  challenge: string;          // base64url
  rpId: string;
  timeout?: number;
  allowCredentials?: Array<{ id: string; type: string; transports?: string[] }>;
  userVerification?: string;
}

// Authentication result (to Cognito)
interface PasskeyGetResultJson {
  id: string;
  rawId: string;              // base64url
  type: string;               // "public-key"
  clientExtensionResults: Record<string, unknown>;
  authenticatorAttachment?: string;
  response: PkcAssertionResponse<string>;  // all fields base64url strings
}
```

---

## 7. Error Handling

### PasskeyError Class and Error Codes

`PasskeyError` extends `AmplifyError` with these error codes:

| Error Code | Message | When Thrown |
|---|---|---|
| `PasskeyNotSupported` | "Passkeys may not be supported on this device." | Platform check fails |
| `PasskeyAlreadyExists` | "Passkey already exists in authenticator." | Duplicate credential |
| `InvalidPasskeyRegistrationOptions` | "Invalid passkey registration options." | Bad Cognito response |
| `InvalidPasskeyAuthenticationOptions` | "Invalid passkey authentication options." | Bad challenge params |
| `RelyingPartyMismatch` | "Relying party does not match current domain." | RP ID mismatch |
| `PasskeyRegistrationFailed` | "Device failed to create passkey." | Platform create() failed |
| `PasskeyRetrievalFailed` | "Device failed to retrieve passkey." | Platform get() failed |
| `PasskeyRegistrationCanceled` | "Passkey registration ceremony has been canceled." | User canceled |
| `PasskeyAuthenticationCanceled` | "Passkey authentication ceremony has been canceled." | User canceled |
| `PasskeyOperationAborted` | "Passkey operation has been aborted." | Operation interrupted |

### Error Handling Functions

- **`handlePasskeyRegistrationError(err)`**: Maps platform errors from `navigator.credentials.create()` to PasskeyError codes
- **`handlePasskeyAuthenticationError(err)`**: Maps platform errors from `navigator.credentials.get()` to PasskeyError codes

### Cognito-Side Errors (from API calls)

| Exception | When |
|---|---|
| `StartWebAuthnRegistrationException` | Cognito fails to generate registration options |
| `CompleteWebAuthnRegistrationException` | Cognito fails to verify registration result |
| `ListWebAuthnCredentialsException` | Cognito fails listing credentials |
| `DeleteWebAuthnCredentialException` | Cognito fails deleting credential |

---

## 8. Amplify UI Authenticator Passkey UX

### State Machine Architecture

The Authenticator uses XState with these passkey-relevant states in the `signIn` actor:

```
signIn
  |-- edit                     # Username/password input
  |-- selectMethod             # Auth method selection (PASSWORD, EMAIL_OTP, SMS_OTP, WEB_AUTHN)
  |-- submit                   # Processing sign-in
  |-- checkPasskeys            # Invokes listWebAuthnCredentials() to detect existing passkeys
  |-- passkeyPrompt            # Prompts user to register a passkey
  |-- resolved                 # Sign-in complete
```

### State Transitions

**selectMethod state:**
```
entry: [sendUpdate, setSelectAuthMethodStep, setUsernameSignIn]
on:
  SELECT_METHOD -> submit  (sets selectedAuthMethod)
  SUBMIT -> submit         (sets selectedAuthMethod from form)
  SIGN_IN -> edit          (go back)
```

**Challenge selection logic:**
```typescript
// Determines auth method to use
const method = selectedAuthMethod
  ?? preferredChallenge
  ?? availableAuthMethods?.[0]
  ?? 'PASSWORD';
```

### Guards (Conditional Transitions)

| Guard | Purpose |
|---|---|
| `shouldSelectAuthMethod` | Show method selection when multiple methods available AND (no preferred challenge OR user cleared selection) |
| `shouldPromptPasskeyRegistration` | After sign-in: `passkeyRegistrationPrompts` exists AND user has no existing passkeys AND setting is `'ALWAYS'` |
| `shouldPromptPasskeyRegistrationAfterSignup` | Same logic but checks `afterSignup` setting |
| `hasPasskeyRegistrationPrompts` | Whether `passwordless.passkeyRegistrationPrompts` is configured |
| `shouldReturnToSelectMethod` | Allow navigating back to selection screen |

### Authenticator Component Props

```jsx
<Authenticator
  passwordless={{
    // Hide specific auth methods from selection UI
    hiddenAuthMethods: ['PASSWORD'],

    // Default auth method
    preferredAuthMethod: 'WEB_AUTHN',

    // When to prompt passkey registration
    passkeyRegistrationPrompts: {
      afterSignin: 'ALWAYS' | 'NEVER',
      afterSignup: 'ALWAYS' | 'NEVER',
    },
    // Or disable entirely:
    // passkeyRegistrationPrompts: false,
  }}
/>
```

### Passkey Registration Prompt Flow

After sign-in/sign-up, if configured:
1. `checkPasskeys` state invokes `listWebAuthnCredentials()` to check if user has passkeys
2. If no passkeys and prompt is configured, transitions to `passkeyPrompt` state
3. Prompt exposes two actions:
   - `createPasskey()` -> calls `associateWebAuthnCredential()` -> triggers platform ceremony
   - `skip()` -> continues to authenticated state

### CSS Selectors for Passkey Components

```css
[data-amplify-authenticator-passkeyPrompt]    /* Passkey prompt container */
[data-amplify-authenticator-signinselect]      /* Auth method selection */
```

### Error Display in UI

The Authenticator actions handle passkey ceremony cancellation:
```typescript
if (message.includes('ceremony has been canceled')) {
  // Show translated error for user-canceled passkey ceremony
}
```

---

## 9. Complete Sign-In Flow Diagram

```
Developer calls signIn({ username, options: { authFlowType: 'USER_AUTH' } })
  |
  +--> [preferredChallenge specified?]
  |     |
  |     YES: Include PREFERRED_CHALLENGE in InitiateAuth
  |     |     |
  |     |     +--> Cognito returns WEB_AUTHN challenge
  |     |     |     with CREDENTIAL_REQUEST_OPTIONS
  |     |     |     |
  |     |     |     +--> handleWebAuthnSignInResult()
  |     |     |           |
  |     |     |           +--> getPasskey(parse(CREDENTIAL_REQUEST_OPTIONS))
  |     |     |           |     |
  |     |     |           |     +--> [Web] navigator.credentials.get({ publicKey })
  |     |     |           |     +--> [RN]  rtn-passkeys.getPasskey()
  |     |     |           |
  |     |     |           +--> respondToAuthChallenge({ CREDENTIAL: serialize(result) })
  |     |     |           |
  |     |     |           +--> Return DONE or next MFA challenge
  |     |     |
  |     |     +--> Cognito returns SELECT_CHALLENGE (preferred unavailable)
  |     |           (falls through to NO path)
  |     |
  |     NO: No PREFERRED_CHALLENGE in InitiateAuth
  |           |
  |           +--> Cognito returns SELECT_CHALLENGE
  |                 with AvailableChallenges
  |                 |
  |                 +--> nextStep = CONTINUE_SIGN_IN_WITH_FIRST_FACTOR_SELECTION
  |                       |
  |                       +--> Developer/UI shows challenge selection
  |                       |
  |                       +--> confirmSignIn({ challengeResponse: 'WEB_AUTHN' })
  |                             |
  |                             +--> initiateSelectedChallenge()
  |                             |     respondToAuthChallenge({
  |                             |       ChallengeName: 'SELECT_CHALLENGE',
  |                             |       ANSWER: 'WEB_AUTHN'
  |                             |     })
  |                             |
  |                             +--> Cognito returns WEB_AUTHN challenge
  |                             |     with CREDENTIAL_REQUEST_OPTIONS
  |                             |
  |                             +--> handleWebAuthnSignInResult()
  |                                   (same as above)
```

---

## 10. Implications for amplify-flutter

### What to Replicate

1. **Platform abstraction pattern:** Create a `PasskeyPlatform` interface with `getPasskey()` and `registerPasskey()` methods, with implementations for web (dart:html/web), Android (Credential Manager), and iOS (ASAuthorization).

2. **Serialization layer:** Build equivalent serde for Dart. The JSON types (`PasskeyCreateOptionsJson`, `PasskeyCreateResultJson`, etc.) should map directly. Use `dart:convert` for base64url encoding.

3. **Error taxonomy:** Mirror the `PasskeyErrorCode` enum. Map platform-specific errors to these codes.

4. **Three-phase registration:** Same flow: `StartWebAuthnRegistration` -> platform ceremony -> `CompleteWebAuthnRegistration`.

5. **Two-step SELECT_CHALLENGE for WEB_AUTHN:** Respond to SELECT_CHALLENGE with `ANSWER: "WEB_AUTHN"` first, then handle the WEB_AUTHN challenge with CREDENTIAL_REQUEST_OPTIONS.

6. **Authenticator state machine states:** Add `selectMethod` and `passkeyPrompt` states to the Flutter Authenticator's state machine.

### What Differs

1. **No file extension switching:** Flutter uses platform channels/conditional imports instead of `.native.ts` files. Use `dart:html` conditionals or federated plugins.

2. **Missing Cognito APIs:** The Flutter SDK does not yet have `StartWebAuthnRegistration`, `CompleteWebAuthnRegistration`, `ListWebAuthnCredentials`, or `DeleteWebAuthnCredential` operations. These need to be added to the Smithy model or called via raw HTTP.

3. **React Native Turbo Module vs Flutter Plugin:** The `rtn-passkeys` package pattern maps to a Flutter federated plugin with platform implementations for Android/iOS/Web.

4. **Session persistence:** amplify-js persists sign-in session across page refreshes. Flutter needs equivalent state persistence for multi-step flows.

### Implementation Priority

Based on the amplify-js architecture, the recommended build order is:

1. **Passkey platform abstraction** (getPasskey, registerPasskey, isSupported) - Web first, then iOS/Android
2. **Serde layer** (JSON types, base64url conversion)
3. **Sign-in flow** (handleWebAuthnSignInResult equivalent in SignInStateMachine)
4. **SELECT_CHALLENGE handling** (two-step flow)
5. **Registration APIs** (StartWebAuthnRegistration/CompleteWebAuthnRegistration Cognito operations)
6. **associateWebAuthnCredential** high-level API
7. **Credential management** (list/delete)
8. **Authenticator UI** (method selection, passkey prompt)

---

## Sources

### amplify-js GitHub Source Code
- [packages/auth/src/index.ts](https://github.com/aws-amplify/amplify-js/blob/main/packages/auth/src/index.ts) - WebAuthn API exports
- [packages/auth/src/client/flows/userAuth/](https://github.com/aws-amplify/amplify-js/tree/main/packages/auth/src/client/flows/userAuth) - USER_AUTH flow handlers
- [packages/auth/src/client/utils/passkey/](https://github.com/aws-amplify/amplify-js/tree/main/packages/auth/src/client/utils/passkey) - Passkey utilities
- [packages/auth/src/client/apis/associateWebAuthnCredential.ts](https://github.com/aws-amplify/amplify-js/blob/main/packages/auth/src/client/apis/associateWebAuthnCredential.ts) - Registration API
- [packages/rtn-passkeys/](https://github.com/aws-amplify/amplify-js/tree/main/packages/rtn-passkeys) - React Native Turbo Module

### amplify-ui GitHub Source Code
- [packages/ui/src/machines/authenticator/](https://github.com/aws-amplify/amplify-ui/tree/main/packages/ui/src/machines/authenticator) - State machine
- [packages/ui/src/machines/authenticator/actors/signIn.ts](https://github.com/aws-amplify/amplify-ui/blob/main/packages/ui/src/machines/authenticator/actors/signIn.ts) - Sign-in actor
- [packages/ui/src/machines/authenticator/guards.ts](https://github.com/aws-amplify/amplify-ui/blob/main/packages/ui/src/machines/authenticator/guards.ts) - State guards
- [packages/ui/src/machines/authenticator/actions.ts](https://github.com/aws-amplify/amplify-ui/blob/main/packages/ui/src/machines/authenticator/actions.ts) - State actions

### Official Documentation
- [Passwordless Authentication](https://docs.amplify.aws/react/build-a-backend/auth/concepts/passwordless/) - Concept overview
- [Sign-in with Passkey](https://docs.amplify.aws/react/build-a-backend/auth/connect-your-frontend/sign-in/) - Sign-in API usage
- [Multi-step Sign-in](https://docs.amplify.aws/react/build-a-backend/auth/connect-your-frontend/multi-step-sign-in/) - Challenge handling
- [Manage WebAuthn Credentials](https://docs.amplify.aws/react/build-a-backend/auth/manage-users/manage-webauthn-credentials/) - Credential management
- [Authenticator Configuration](https://ui.docs.amplify.aws/react/connected-components/authenticator/configuration) - UI component props

### GitHub Issues
- [amplify-js #14419 - Passkey registration security](https://github.com/aws-amplify/amplify-js/issues/14419)
- [amplify-flutter #5788 - Passkey login not supported in Authenticator UI](https://github.com/aws-amplify/amplify-flutter/issues/5788)

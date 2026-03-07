# Cognito WebAuthn/Passkey API Research

**Researched:** 2026-03-07
**Overall confidence:** HIGH (SDK models in codebase + official AWS documentation)

## Executive Summary

AWS Cognito has native WebAuthn/passkey support built into its choice-based authentication system. Passkeys operate through two distinct flows: a **registration flow** (post-authentication, token-authorized) and a **sign-in flow** (via the `USER_AUTH` auth flow with `WEB_AUTHN` challenge type). The existing amplify-flutter SDK models already include all the necessary enum values (`USER_AUTH`, `WEB_AUTHN`, `SELECT_CHALLENGE`) and response fields (`availableChallenges`), but no application-level logic handles these challenge types yet.

---

## 1. Passkey Sign-In Flow

### Overview

Passkey sign-in uses the `USER_AUTH` auth flow (choice-based authentication). This is the only auth flow that supports passkeys. The user pool must have `ALLOW_USER_AUTH` enabled and passkeys configured as an allowed first factor.

### Step-by-Step API Flow

#### Option A: Direct WEB_AUTHN (preferred challenge specified)

```
Step 1: InitiateAuth
  Request:
    AuthFlow: "USER_AUTH"
    AuthParameters:
      USERNAME: "<username>"
      PREFERRED_CHALLENGE: "WEB_AUTHN"

  Response:
    ChallengeName: "WEB_AUTHN"
    ChallengeParameters:
      CREDENTIAL_REQUEST_OPTIONS: "<JSON string>"   // PublicKeyCredentialRequestOptions
    AvailableChallenges: ["PASSWORD_SRP", "PASSWORD", "EMAIL_OTP", "WEB_AUTHN"]
    Session: "<session token>"

Step 2: Client-side WebAuthn ceremony
  Parse CREDENTIAL_REQUEST_OPTIONS JSON -> pass to platform WebAuthn API
  Platform returns AuthenticationResponseJSON (PublicKeyCredential serialized)

Step 3: RespondToAuthChallenge
  Request:
    ChallengeName: "WEB_AUTHN"
    ChallengeResponses:
      USERNAME: "<username>"
      CREDENTIAL: "<AuthenticationResponseJSON string>"
      SECRET_HASH: "<if app client has secret>"
    Session: "<session from step 1>"

  Response:
    AuthenticationResult: { ... tokens ... }   // if no MFA
    -- OR --
    ChallengeName: "SMS_MFA" / "SOFTWARE_TOKEN_MFA"   // if MFA required
```

#### Option B: SELECT_CHALLENGE flow (no preferred challenge)

```
Step 1: InitiateAuth
  Request:
    AuthFlow: "USER_AUTH"
    AuthParameters:
      USERNAME: "<username>"
      // No PREFERRED_CHALLENGE

  Response:
    ChallengeName: "SELECT_CHALLENGE"
    AvailableChallenges: ["PASSWORD_SRP", "PASSWORD", "EMAIL_OTP", "WEB_AUTHN", "SMS_OTP"]
    Session: "<session token>"

Step 2: RespondToAuthChallenge (select + authenticate in one call)
  Request:
    ChallengeName: "SELECT_CHALLENGE"
    ChallengeResponses:
      USERNAME: "<username>"
      ANSWER: "WEB_AUTHN"
      CREDENTIAL: "<AuthenticationResponseJSON string>"
    Session: "<session from step 1>"

  Response:
    AuthenticationResult: { ... tokens ... }
```

**KEY INSIGHT:** When selecting `WEB_AUTHN` via `SELECT_CHALLENGE`, you can complete authentication in a single `RespondToAuthChallenge` call by including both `ANSWER: "WEB_AUTHN"` and `CREDENTIAL: "<json>"` in the challenge responses. This is different from `SMS_OTP` and `EMAIL_OTP` which require a two-step process (select first, then provide code).

However, for `WEB_AUTHN` via `SELECT_CHALLENGE`, you still need the `CREDENTIAL_REQUEST_OPTIONS` to perform the WebAuthn ceremony. The question is: **where do you get `CREDENTIAL_REQUEST_OPTIONS` when using `SELECT_CHALLENGE`?**

Based on the SDK documentation pattern, when `SELECT_CHALLENGE` is returned with `WEB_AUTHN` in `AvailableChallenges`, the `ChallengeParameters` should contain `CREDENTIAL_REQUEST_OPTIONS`. If not present at the SELECT_CHALLENGE step, the client may need to respond with just `ANSWER: "WEB_AUTHN"` first, receive a `WEB_AUTHN` challenge with `CREDENTIAL_REQUEST_OPTIONS`, then complete the ceremony.

**Confidence: MEDIUM** -- The exact behavior when using SELECT_CHALLENGE with WEB_AUTHN (whether CREDENTIAL_REQUEST_OPTIONS is included in the SELECT_CHALLENGE response or requires an intermediate step) needs runtime verification.

### CREDENTIAL_REQUEST_OPTIONS Format

The `CREDENTIAL_REQUEST_OPTIONS` value in `ChallengeParameters` is a JSON-serialized `PublicKeyCredentialRequestOptions` object (W3C WebAuthn Level 3 spec):

```json
{
  "challenge": "<base64url-encoded challenge>",
  "rpId": "auth.example.com",
  "allowCredentials": [
    {
      "id": "<base64url-encoded credential ID>",
      "type": "public-key",
      "transports": ["internal", "hybrid"]
    }
  ],
  "timeout": 60000,
  "userVerification": "preferred"
}
```

### AuthenticationResponseJSON Format (CREDENTIAL)

The `CREDENTIAL` value sent back in `ChallengeResponses` must be the JSON serialization per W3C WebAuthn Level 3 `AuthenticationResponseJSON`:

```json
{
  "id": "<base64url credential ID>",
  "rawId": "<base64url credential ID>",
  "type": "public-key",
  "response": {
    "authenticatorData": "<base64url>",
    "clientDataJSON": "<base64url>",
    "signature": "<base64url>",
    "userHandle": "<base64url>"
  },
  "clientExtensionResults": {},
  "authenticatorAttachment": "platform"
}
```

**Confidence: HIGH** -- This follows the W3C WebAuthn Level 3 spec dictionaries; confirmed by SDK doc references to `AuthenticationResponseJSON`.

---

## 2. Passkey Registration Flow

Registration is a **post-authentication operation** -- the user must already be signed in. It uses token-authorized API calls (not the InitiateAuth/RespondToAuthChallenge flow).

### Step-by-Step API Flow

```
Step 1: StartWebAuthnRegistration
  Request:
    AccessToken: "<user's access token>"
    // Access token must have scope: aws.cognito.signin.user.admin

  Response:
    CredentialCreationOptions: {
      "rp": {
        "id": "auth.example.com",
        "name": "My App"
      },
      "user": {
        "id": "<base64url user ID>",
        "name": "<username>",
        "displayName": "<user display name>"
      },
      "challenge": "<base64url challenge>",
      "pubKeyCredParams": [
        { "type": "public-key", "alg": -7 },     // ES256
        { "type": "public-key", "alg": -257 }    // RS256
      ],
      "authenticatorSelection": {
        "requireResidentKey": true,
        "residentKey": "required",
        "userVerification": "preferred"
      },
      "excludeCredentials": [
        {
          "id": "<base64url existing credential ID>",
          "type": "public-key"
        }
      ],
      "timeout": 60000
    }

Step 2: Client-side WebAuthn ceremony
  Pass CredentialCreationOptions to platform WebAuthn API
  (navigator.credentials.create() on web, platform-specific on mobile)
  Platform returns RegistrationResponseJSON (PublicKeyCredential)

Step 3: CompleteWebAuthnRegistration
  Request:
    AccessToken: "<user's access token>"
    Credential: <RegistrationResponseJSON>

  Response:
    HTTP 200 with empty body (success)
```

### RegistrationResponseJSON Format (Credential for CompleteWebAuthnRegistration)

```json
{
  "id": "<base64url credential ID>",
  "rawId": "<base64url credential ID>",
  "type": "public-key",
  "response": {
    "attestationObject": "<base64url>",
    "clientDataJSON": "<base64url>",
    "transports": ["internal", "hybrid"],
    "publicKeyAlgorithm": -7,
    "publicKey": "<base64url>",
    "authenticatorData": "<base64url>"
  },
  "clientExtensionResults": {},
  "authenticatorAttachment": "platform"
}
```

### Cognito-Specific Registration Details

- **Max passkeys per user:** 20
- **Supported algorithms:** ES256 (alg: -7) and RS256 (alg: -257)
- **Relying Party ID:** Configurable; defaults to managed login custom domain or prefix domain
- **Authenticator types:** Both `platform` (biometrics) and `cross-platform` (security keys) supported
- **Resident key:** Required (discoverable credentials)

**Confidence: HIGH** -- Directly from AWS API documentation.

---

## 3. Credential Management APIs

All token-authorized (access token with `aws.cognito.signin.user.admin` scope).

### ListWebAuthnCredentials

```
Request:
  AccessToken: "<user's access token>"
  MaxResults: <optional int>
  NextToken: "<optional pagination token>"

Response:
  Credentials: [
    {
      CredentialId: "<credential ID>",
      FriendlyCredentialName: "<auto-generated name>",
      RelyingPartyId: "auth.example.com",
      AuthenticatorAttachment: "platform" | "cross-platform",
      AuthenticatorTransports: ["internal", "hybrid"],
      CreatedAt: <unix timestamp>
    }
  ]
  NextToken: "<pagination token if more>"
```

### DeleteWebAuthnCredential

```
Request:
  AccessToken: "<user's access token>"
  CredentialId: "<credential ID from ListWebAuthnCredentials>"

Response:
  HTTP 200 with empty body (success)
```

**Confidence: HIGH** -- From AWS API documentation.

---

## 4. SELECT_CHALLENGE / Choice-Based Authentication Details

### How It Works

The `SELECT_CHALLENGE` mechanism is Cognito's way of presenting multiple first-factor options to the user. It is returned when:
1. `AuthFlow` is `USER_AUTH` AND
2. No `PREFERRED_CHALLENGE` is specified (or the preferred one is unavailable)

### Available First Factors

The `AvailableChallenges` field in the `InitiateAuth` response lists which challenges are available. Possible values:
- `PASSWORD` -- Direct password
- `PASSWORD_SRP` -- SRP-based password
- `WEB_AUTHN` -- Passkey
- `EMAIL_OTP` -- Email one-time password
- `SMS_OTP` -- SMS one-time password

### Existing Codebase Support

The amplify-flutter SDK already has infrastructure for this:

- **`InitiateAuthResponse.availableChallenges`** -- `BuiltList<ChallengeNameType>?` field already present
- **`ChallengeNameType.selectChallenge`** -- Enum value exists
- **`ChallengeNameType.webAuthn`** -- Enum value exists
- **`AuthFlowType.userAuth`** -- Enum value exists
- **`SignInStateMachine._availableChallenges`** -- Already stored from InitiateAuth response
- **`SignInStateMachine._allowedFirstFactorTypes`** -- Maps `availableChallenges` to `AuthFactorType` set

### What Is NOT Implemented

- No handling of `WEB_AUTHN` in `createRespondToAuthChallengeRequest`
- No handling of `SELECT_CHALLENGE` in the challenge processing logic
- No `CREDENTIAL_REQUEST_OPTIONS` parsing
- No `StartWebAuthnRegistration` / `CompleteWebAuthnRegistration` API calls in the SDK client
- No platform bridge for WebAuthn ceremonies (the actual biometric/passkey prompt)

**Confidence: HIGH** -- Verified by reading the actual codebase.

---

## 5. autoSignIn and Passkey Enrollment

### Key Constraint

Users **cannot** register a passkey during sign-up. They must:
1. Sign up with another method (password, email OTP, SMS OTP)
2. Complete sign-up confirmation
3. Sign in (autoSignIn or manual)
4. **Then** call `StartWebAuthnRegistration` / `CompleteWebAuthnRegistration` while authenticated

### autoSignIn Flow

The existing `autoSignIn` flow works as follows:
1. `signUp()` with `autoSignIn: true`
2. After confirmation, Amplify automatically calls `signIn()`
3. User gets tokens

For passkey enrollment after auto-sign-in:
1. User signs up with password/OTP
2. autoSignIn completes, user has access token
3. App calls `associateWebAuthnCredential()` (Amplify JS name) which:
   a. Calls `StartWebAuthnRegistration` with access token
   b. Triggers platform WebAuthn ceremony
   c. Calls `CompleteWebAuthnRegistration` with result

### Important Limitation

autoSignIn does NOT work across sessions/tabs. If the user confirms via email link in a new tab, autoSignIn will fail. This is a known limitation (amplify-js issue #10225).

**Confidence: HIGH** -- From Amplify JS documentation and issue discussions.

---

## 6. MFA Interaction with Passkeys

### Critical Constraint

Passkey sign-in is **not compatible with required MFA**:
- If MFA is **required** at the user pool level: passkey sign-in will not work
- If MFA is **optional**: users who have personally enabled MFA cannot sign in with passkeys
- Passkeys are considered a strong first factor (multi-factor by nature: possession + biometric) so MFA is redundant

### Practical Impact

When implementing, the state machine should:
- Not offer MFA setup after passkey sign-in
- Not prompt for MFA challenges after successful passkey authentication
- Handle the case where a user has MFA enabled but tries passkey sign-in (Cognito may return only `PASSWORD`/`PASSWORD_SRP` in `AvailableChallenges`, excluding `WEB_AUTHN`)

**Confidence: HIGH** -- AWS documentation explicitly states this limitation.

---

## 7. Error Cases

### Registration Errors

| Error | Cause |
|-------|-------|
| `WebAuthnNotEnabledException` | Passkey feature not enabled for user pool |
| `WebAuthnOriginNotAllowedException` | Registration origin doesn't match RP ID |
| `WebAuthnCredentialNotSupportedException` | Unsupported device/provider |
| `WebAuthnChallengeNotFoundException` | Challenge from StartWebAuthnRegistration expired |
| `WebAuthnClientMismatchException` | Access token from different client than StartWebAuthnRegistration |
| `LimitExceededException` | User already has 20 passkeys |

### Sign-In Errors

| Error | Cause |
|-------|-------|
| `NotAuthorizedException` | Invalid credential or session expired |
| `InvalidParameterException` | Malformed CREDENTIAL JSON |

**Confidence: MEDIUM** -- Error names from API docs; exact error handling behavior needs runtime verification.

---

## 8. Existing SDK Gaps

The following Cognito API operations are **NOT present** in the generated SDK client (`packages/auth/amplify_auth_cognito_dart/lib/src/sdk/`):

1. **`StartWebAuthnRegistration`** -- No model or operation
2. **`CompleteWebAuthnRegistration`** -- No model or operation
3. **`ListWebAuthnCredentials`** -- No model or operation
4. **`DeleteWebAuthnCredential`** -- No model or operation
5. **`WebAuthnCredentialDescription`** -- No model type

These operations need to be added to the Smithy model and code-generated, OR called via raw HTTP against the Cognito Identity Provider service endpoint.

The sign-in flow operations (`InitiateAuth`, `RespondToAuthChallenge`) already have the necessary fields (`WEB_AUTHN` challenge, `SELECT_CHALLENGE`, `availableChallenges`, `USER_AUTH` flow type) but no application logic handles them.

**Confidence: HIGH** -- Verified by grep of the SDK source code.

---

## 9. Platform-Specific WebAuthn Implementation Requirements

### What the Flutter Client Must Do

The Cognito API handles server-side WebAuthn logic. The Flutter client is responsible for:

1. **Registration:** Take `CredentialCreationOptions` from `StartWebAuthnRegistration` response, call platform WebAuthn API, return `RegistrationResponseJSON` to `CompleteWebAuthnRegistration`
2. **Sign-in:** Take `CREDENTIAL_REQUEST_OPTIONS` from challenge parameters, call platform WebAuthn API, return `AuthenticationResponseJSON` as `CREDENTIAL` in `RespondToAuthChallenge`

### Platform APIs Needed

| Platform | API | Notes |
|----------|-----|-------|
| Web | `navigator.credentials.create()` / `navigator.credentials.get()` | Standard WebAuthn JavaScript API |
| Android | FIDO2 / Credential Manager API | Google Play Services required |
| iOS | `ASAuthorizationPlatformPublicKeyCredentialProvider` | iOS 16+ / macOS 13+ |
| Linux/Windows | Limited support | May need to use cross-platform authenticators (security keys) |

### Data Format Translation

The Cognito API sends/expects JSON following W3C WebAuthn Level 3 spec dictionaries. The client must handle:
- Base64url encoding/decoding of binary fields (`challenge`, `user.id`, credential `id`, `authenticatorData`, etc.)
- Conversion between JSON and platform-specific data structures
- `ArrayBuffer` (web) / `ByteArray` (native) handling

**Confidence: HIGH** for web/Android/iOS requirements. **LOW** for Linux/Windows -- needs further investigation.

---

## Sources

- [AWS Cognito Authentication Documentation](https://docs.aws.amazon.com/cognito/latest/developerguide/authentication.html)
- [AWS Cognito Authentication Flows](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-authentication-flow-methods.html)
- [Manage authentication methods in AWS SDKs](https://docs.aws.amazon.com/cognito/latest/developerguide/authentication-flows-selection-sdk.html)
- [InitiateAuth API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_InitiateAuth.html)
- [RespondToAuthChallenge API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_RespondToAuthChallenge.html)
- [StartWebAuthnRegistration API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_StartWebAuthnRegistration.html)
- [CompleteWebAuthnRegistration API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_CompleteWebAuthnRegistration.html)
- [ListWebAuthnCredentials API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_ListWebAuthnCredentials.html)
- [DeleteWebAuthnCredential API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_DeleteWebAuthnCredential.html)
- [WebAuthnCredentialDescription API Reference](https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_WebAuthnCredentialDescription.html)
- [AWS Blog: Password-less authentication with Cognito and WebAuthn](https://aws.amazon.com/blogs/security/how-to-implement-password-less-authentication-with-amazon-cognito-and-webauthn/)
- [Amplify JS WebAuthn Credential Management](https://docs.amplify.aws/react/build-a-backend/auth/manage-users/manage-webauthn-credentials/)
- [Amplify JS Sign-in Documentation](https://docs.amplify.aws/react/build-a-backend/auth/connect-your-frontend/sign-in/)
- [Amplify JS Multi-step Sign-in](https://docs.amplify.aws/react/build-a-backend/auth/connect-your-frontend/multi-step-sign-in/)
- [W3C WebAuthn Level 3 Spec - AuthenticationResponseJSON](https://www.w3.org/TR/WebAuthn-3/#dictdef-authenticationresponsejson)
- [W3C WebAuthn Level 3 Spec - RegistrationResponseJSON](https://www.w3.org/TR/WebAuthn-3/#dictdef-registrationresponsejson)

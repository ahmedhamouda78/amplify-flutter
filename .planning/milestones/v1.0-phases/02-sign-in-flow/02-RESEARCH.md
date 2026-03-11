# Phase 2: Sign-In Flow — State Machine WEB_AUTHN Integration — Research

## 1. Architecture Overview of the Auth State Machine

### State Machine Hierarchy

The auth system uses a hierarchical state machine pattern managed by `CognitoAuthStateMachine` (a `StateMachineManager`). Individual flows are handled by specialized state machines:

- `SignInStateMachine` -- handles all sign-in flows
- `SignUpStateMachine` -- handles sign-up
- `FetchAuthSessionStateMachine` -- handles session management
- `HostedUiStateMachine` -- handles OAuth/hosted UI
- `TotpSetupStateMachine` -- handles TOTP setup

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

### Sign-In State Machine Lifecycle

The `SignInStateMachine` operates as a loop:

```
1. resolve(SignInInitiate) -> run(event)
2. run() builds InitiateAuthRequest -> calls cognitoIdp.initiateAuth()
3. Response sets: _authenticationResult, _challengeName, _challengeParameters, _session
4. _processChallenge(event) is called:
   a. If _authenticationResult != null -> SignInState.success (done)
   b. Otherwise -> createRespondToAuthChallengeRequest()
      - If request is null -> return SignInState.challenge (yields to user)
      - If request is built -> emit challenge state, then _respondToChallenge()
5. _respondToChallenge() calls cognitoIdp.respondToAuthChallenge()
6. Updates flow state from response, calls _processChallenge() again (loop)
```

When the machine yields (returns `SignInState.challenge`), the plugin layer converts that to a `CognitoSignInResult` with the appropriate `AuthSignInStep`. The user then calls `confirmSignIn()`, which dispatches `SignInRespondToChallenge`, and the `resolve()` method calls `_processChallenge(event)` to resume.

### Key State Machine Fields

```dart
AuthenticationResultType? _authenticationResult;  // Set when flow is complete
ChallengeNameType? _challengeName;                // Current challenge type
BuiltMap<String, String?> _challengeParameters;   // Challenge params from Cognito
BuiltList<ChallengeNameType> _availableChallenges; // For SELECT_CHALLENGE
String? _session;                                  // Session token for next request
```

### Events and States

- **Events** (`sign_in_event.dart`):
  - `SignInInitiate` -- starts sign-in with auth flow type and parameters
  - `SignInRespondToChallenge` -- user response with `answer` string
  - `SignInCancelled` / `SignInSucceeded`

- **States** (`sign_in_state.dart`):
  - `SignInNotStarted` / `SignInInitiating`
  - `SignInChallenge` -- paused, waiting for user input; carries challenge name, params, allowed factors
  - `SignInSuccess` / `SignInFailure`

### Dependency Injection

The `CognitoAuthStateMachine` extends `StateMachineManager` with a `DependencyManager`. Dependencies are registered with `addInstance<T>(instance)` and retrieved with `get<T>()`, `expect<T>()`, or `getOrCreate<T>()`. The Flutter wrapper (`AmplifyAuthCognito`) adds platform-specific instances in `addPlugin()`.

**This is how `WebAuthnCredentialPlatform` will be injected.** The platform bridge instance must be registered with the state machine before sign-in flows can use it.

---

## 2. How Existing Challenge Types Are Handled (Pattern)

### Challenge Dispatch in createRespondToAuthChallengeRequest()

The core dispatch method (line ~348-390) pattern-matches on `ChallengeNameType`:

```dart
Future<RespondToAuthChallengeRequest?> createRespondToAuthChallengeRequest(
  SignInEvent? event,
  ChallengeNameType challengeName,
  BuiltMap<String, String?> challengeParameters,
) async {
  final hasUserResponse = event is SignInRespondToChallenge;
  return switch (challengeName) {
    ChallengeNameType.customChallenge when hasUserResponse => createCustomAuthRequest(event),
    ChallengeNameType.passwordVerifier => createPasswordVerifierRequest(challengeParameters),
    ChallengeNameType.smsMfa when hasUserResponse => createSmsMfaRequest(event),
    ChallengeNameType.selectChallenge when hasUserResponse => createSelectFirstFactorRequest(event),
    // ... more cases ...
    _ => null,  // null = yield to user for input
  };
}
```

**Two categories of challenges:**

1. **Automatic** (no `when hasUserResponse` guard): `passwordVerifier`, `deviceSrpAuth`, `devicePasswordVerifier` -- the machine responds internally without user input.

2. **User-input required** (guarded by `when hasUserResponse`): `smsMfa`, `softwareTokenMfa`, `emailOtp`, `smsOtp`, `selectMfaType`, `newPasswordRequired`, `selectChallenge`, `password`, `passwordSrp` -- returns `null` first time (yielding challenge state to user), then handles on second pass when user provides answer.

### Challenge-to-SignInStep Mapping (sdk_bridge.dart)

`ChallengeNameTypeBridge.signInStep` maps each `ChallengeNameType` to an `AuthSignInStep` for the plugin layer:

```dart
ChallengeNameType.selectChallenge => AuthSignInStep.continueSignInWithFirstFactorSelection,
ChallengeNameType.webAuthn => throw InvalidStateException(...), // Phase 1 placeholder
```

### SELECT_CHALLENGE Flow (Existing Pattern)

The `createSelectFirstFactorRequest()` method (line ~858-896) handles user selection of a first factor:

```dart
Future<RespondToAuthChallengeRequest?> createSelectFirstFactorRequest(
  SignInRespondToChallenge event,
) async {
  final answer = event.answer.toUpperCase();
  final selectedFactor = AuthFactorType.values
      .where((factor) => factor.value == answer)
      .firstOrNull;
  // ...
  // Special handling for password/passwordSrp (returns null to trigger password input)
  if (selectedFactor == AuthFactorType.password) {
    _challengeName = ChallengeNameType.password;
    return null;
  }
  // For others, sends ANSWER to Cognito
  return RespondToAuthChallengeRequest.build((b) {
    b
      ..challengeName = ChallengeNameType.selectChallenge
      ..challengeResponses.addAll({
        CognitoConstants.challengeParamUsername: cognitoUsername,
        CognitoConstants.challengeParamAnswer: selectedFactor.value,
        // ...
      })
      ..clientId = _authOutputs.userPoolClientId;
  });
}
```

### Available First Factor Types Resolution

`_allowedFirstFactorTypes` (line ~234-252) converts `_availableChallenges` (a `BuiltList<ChallengeNameType>`) to `Set<AuthFactorType>?` by matching `.value` strings. Since Phase 1 uncommented `AuthFactorType.webAuthn`, `ChallengeNameType.webAuthn` in `availableChallenges` already resolves to `AuthFactorType.webAuthn`.

### Plugin Layer Translation

`_processSignInResult()` in `auth_plugin_impl.dart` (line ~472) translates:
- `SignInChallenge.challengeName.signInStep` -> `AuthNextSignInStep.signInStep`
- `SignInChallenge.allowedfirstFactorTypes` -> `AuthNextSignInStep.availableFactors`

---

## 3. What Phase 1 Built and Where Artifacts Live

### Phase 1 Artifacts Inventory

| Artifact | File Path | Purpose |
|----------|-----------|---------|
| `AuthFactorType.webAuthn` | `packages/amplify_core/lib/src/types/auth/sign_in/auth_factor_type.dart` | Enum value `webAuthn('WEB_AUTHN')` with `@JsonValue` annotation |
| Passkey types | `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/passkey_types.dart` (631 lines) | 11 model classes: `PasskeyGetOptions`, `PasskeyGetResult`, `PasskeyAssertionResponse`, `PasskeyCreateOptions`, `PasskeyCreateResult`, etc. |
| Base64url utilities | `packages/auth/amplify_auth_cognito_dart/lib/src/util/base64url_encode.dart` | `base64UrlEncode` / `base64UrlDecode` helpers |
| Cognito WebAuthn client | `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart` (315 lines) | Raw HTTP client for `StartWebAuthnRegistration`, `CompleteWebAuthnRegistration`, `ListWebAuthnCredentials`, `DeleteWebAuthnCredential` |
| Passkey exceptions | `packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart` (113 lines) | `PasskeyException` + 5 subtypes: `PasskeyNotSupportedException`, `PasskeyCancelledException`, `PasskeyRegistrationFailedException`, `PasskeyAssertionFailedException`, `PasskeyRpMismatchException` |
| Platform interface | `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart` | `abstract interface class WebAuthnCredentialPlatform` with `createCredential()`, `getCredential()`, `isPasskeySupported()` |
| SDK bridge placeholder | `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart` (lines 41-45) | `ChallengeNameType.webAuthn` case throws `InvalidStateException` -- **must be replaced in Phase 2** |
| Barrel exports | `packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart` (lines 52-54) | Exports `passkey_types.dart`, `webauthn_credential_platform.dart`, `cognito_webauthn_client.dart` |

### Key Phase 1 Decisions Relevant to Phase 2

- **JSON string boundary**: `WebAuthnCredentialPlatform.getCredential()` accepts and returns JSON strings. The state machine will call `jsonEncode(PasskeyGetOptions.toJson())` to produce the options JSON and `PasskeyGetResult.fromJson(jsonDecode(responseJson))` to parse the platform response.
- **Exception types**: Platform bridge errors throw `PasskeyAssertionFailedException` or `PasskeyCancelledException`, which already extend `AuthException` and will naturally propagate through `resolveError()`.

---

## 4. The WEB_AUTHN Challenge Flow from Cognito's Perspective

### Flow 1: Direct WEB_AUTHN via PREFERRED_CHALLENGE

```
Client                              Cognito
  |                                    |
  |-- InitiateAuth ------------------>|
  |   AuthFlow: USER_AUTH              |
  |   AuthParameters:                  |
  |     USERNAME: "user"               |
  |     PREFERRED_CHALLENGE: WEB_AUTHN |
  |                                    |
  |<-- InitiateAuthResponse ----------|
  |   ChallengeName: WEB_AUTHN        |
  |   ChallengeParameters:            |
  |     CREDENTIAL_REQUEST_OPTIONS:    |
  |       (JSON PublicKeyCredentialRequestOptions)
  |     USERNAME: "user"               |
  |   Session: "..."                   |
  |                                    |
  | [Platform WebAuthn ceremony]       |
  |                                    |
  |-- RespondToAuthChallenge -------->|
  |   ChallengeName: WEB_AUTHN        |
  |   ChallengeResponses:             |
  |     USERNAME: "user"               |
  |     CREDENTIAL: (JSON AuthenticationResponseJSON)
  |   Session: "..."                   |
  |                                    |
  |<-- RespondToAuthChallengeResp ----|
  |   AuthenticationResult: {...}      |
  |   (tokens)                         |
```

### Flow 2: Two-Step via SELECT_CHALLENGE

```
Client                              Cognito
  |                                    |
  |-- InitiateAuth ------------------>|
  |   AuthFlow: USER_AUTH              |
  |   AuthParameters:                  |
  |     USERNAME: "user"               |
  |                                    |
  |<-- InitiateAuthResponse ----------|
  |   ChallengeName: SELECT_CHALLENGE  |
  |   AvailableChallenges:             |
  |     [WEB_AUTHN, PASSWORD, SMS_OTP] |
  |   Session: "..."                   |
  |                                    |
  | [User selects WEB_AUTHN]           |
  |                                    |
  |-- RespondToAuthChallenge -------->|
  |   ChallengeName: SELECT_CHALLENGE  |
  |   ChallengeResponses:             |
  |     USERNAME: "user"               |
  |     ANSWER: "WEB_AUTHN"            |
  |   Session: "..."                   |
  |                                    |
  |<-- RespondToAuthChallengeResp ----|
  |   ChallengeName: WEB_AUTHN        |
  |   ChallengeParameters:            |
  |     CREDENTIAL_REQUEST_OPTIONS: ...  |
  |     USERNAME: "user"               |
  |   Session: "..."                   |
  |                                    |
  | [Platform WebAuthn ceremony]       |
  |                                    |
  |-- RespondToAuthChallenge -------->|
  |   ChallengeName: WEB_AUTHN        |
  |   ChallengeResponses:             |
  |     USERNAME: "user"               |
  |     CREDENTIAL: (JSON)             |
  |   Session: "..."                   |
  |                                    |
  |<-- RespondToAuthChallengeResp ----|
  |   AuthenticationResult: {...}      |
```

### Key Parameters

- **`CREDENTIAL_REQUEST_OPTIONS`**: A JSON string in the challenge parameters containing `PublicKeyCredentialRequestOptions` with `challenge`, `rpId`, `allowCredentials`, `timeout`, `userVerification`.
- **`CREDENTIAL`**: The challenge response key containing the JSON-serialized `AuthenticationResponseJSON` with `id`, `rawId`, `type`, `response` (containing `clientDataJSON`, `authenticatorData`, `signature`, `userHandle`), and `clientExtensionResults`.

### Constants Needed

A new constant `challengeParamCredentialRequestOptions` = `'CREDENTIAL_REQUEST_OPTIONS'` and `challengeParamCredential` = `'CREDENTIAL'` must be added to `CognitoConstants`.

---

## 5. File Inventory: Which Files Need to Be Modified/Created

### Files to MODIFY

| # | File | Change |
|---|------|--------|
| 1 | `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart` | Add `ChallengeNameType.webAuthn` case to `createRespondToAuthChallengeRequest()` dispatch; add `createWebAuthnRequest()` method that parses `CREDENTIAL_REQUEST_OPTIONS`, calls platform bridge `getCredential()`, and builds `RespondToAuthChallengeRequest` with `CREDENTIAL` response |
| 2 | `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart` | Replace `ChallengeNameType.webAuthn => throw InvalidStateException(...)` with proper `AuthSignInStep` mapping (likely `AuthSignInStep.done` since it auto-completes, or a new transient state) |
| 3 | `packages/auth/amplify_auth_cognito_dart/lib/src/flows/constants.dart` | Add `challengeParamCredentialRequestOptions` and `challengeParamCredential` constants |

### Files That MAY Need Modification

| # | File | Potential Change |
|---|------|-----------------|
| 4 | `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart` | Modify `createSelectFirstFactorRequest()` to handle `webAuthn` selection -- currently it sends `ANSWER: WEB_AUTHN` which will trigger a `WEB_AUTHN` challenge response from Cognito. This already works with the existing generic code path, BUT after the next `RespondToAuthChallenge` returns `WEB_AUTHN`, the machine needs to auto-handle it. |
| 5 | `packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart` (Flutter wrapper) | May need to register `WebAuthnCredentialPlatform` instance in `addPlugin()` |

### Files to CREATE (for tests)

| # | File | Purpose |
|---|------|---------|
| 6 | `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` | Unit tests for WEB_AUTHN challenge handling |

### Files NOT Needing Changes

- `auth_factor_type.dart` -- already has `webAuthn` (Phase 1)
- `passkey_types.dart` -- `PasskeyGetOptions`, `PasskeyGetResult` already defined (Phase 1)
- `webauthn_credential_platform.dart` -- interface already defined (Phase 1)
- `auth_plugin_impl.dart` (Dart) -- `_processSignInResult` already handles `SignInChallenge` generically
- `sign_in_state.dart` / `sign_in_event.dart` -- no changes needed; existing `SignInChallenge` and `SignInRespondToChallenge` types are sufficient

---

## 6. Key Patterns and Conventions to Follow

### Challenge Handler Pattern

Every challenge handler follows this signature:

```dart
@protected
Future<RespondToAuthChallengeRequest> createXxxRequest(
  SignInRespondToChallenge event, // or BuiltMap<String, String?> challengeParameters
) async {
  return RespondToAuthChallengeRequest.build((b) {
    b
      ..challengeName = ChallengeNameType.xxx
      ..challengeResponses.addAll({
        CognitoConstants.challengeParamUsername: cognitoUsername,
        // challenge-specific responses...
      })
      ..clientId = _authOutputs.userPoolClientId
      ..clientMetadata.addAll(event.clientMetadata);
  });
}
```

### Auto-Responding vs User-Input Challenges

WEB_AUTHN is unique -- it is an **automatic** challenge (the state machine can respond without user text input), but it requires an **async platform call** (the WebAuthn ceremony). This makes it most similar to `passwordVerifier` or `deviceSrpAuth` which also auto-respond with computed data.

The WEB_AUTHN handler should NOT have a `when hasUserResponse` guard. It should:
1. Extract `CREDENTIAL_REQUEST_OPTIONS` from `_challengeParameters`
2. Call `webAuthnPlatform.getCredential(optionsJson)`
3. Build the `RespondToAuthChallengeRequest` with `CREDENTIAL: responseJson`

### Accessing the Platform Bridge

```dart
// In SignInStateMachine, retrieve via dependency manager:
WebAuthnCredentialPlatform get _webAuthnPlatform => expect();
// Or with explicit null check for better error messages:
WebAuthnCredentialPlatform get _webAuthnPlatform {
  final platform = get<WebAuthnCredentialPlatform>();
  if (platform == null) {
    throw const PasskeyNotSupportedException(
      'No WebAuthn platform bridge is registered.',
    );
  }
  return platform;
}
```

### Constants Convention

All challenge parameter keys are defined as `static const` in `CognitoConstants` with dartdoc.

### Import Conventions

The state machine file imports from:
- `package:amplify_auth_cognito_dart/amplify_auth_cognito_dart.dart` (barrel)
- `package:amplify_auth_cognito_dart/src/...` (internal, with `// ignore: implementation_imports` when crossing package boundaries)

### Error Handling Convention

Errors during challenge handling propagate through `resolveError()` which wraps them in `SignInFailure`. Passkey exceptions (`PasskeyAssertionFailedException`, `PasskeyCancelledException`) already extend `AuthException` and will be properly caught.

---

## 7. Risk Areas and Edge Cases

### Risk 1: WEB_AUTHN Challenge Requires Unique Handling Pattern

Unlike other challenges that either auto-respond synchronously (SRP) or wait for user text input (MFA codes), WEB_AUTHN auto-responds but involves an async platform call with potential user interaction (biometric prompt). The state machine must emit a challenge state (so the UI knows something is happening) before calling the platform bridge, then auto-continue once the bridge returns.

**Mitigation:** Model after `passwordVerifier` -- it auto-responds without user input. The platform WebAuthn ceremony (biometric prompt) is transparent to the state machine. If the user cancels the biometric, the platform bridge throws `PasskeyCancelledException`, which propagates as `SignInFailure`.

### Risk 2: sdk_bridge.dart signInStep Mapping for WEB_AUTHN

Currently `ChallengeNameType.webAuthn` throws `InvalidStateException`. Since WEB_AUTHN auto-completes (the state machine handles it internally), the `signInStep` getter should ideally never be called for `WEB_AUTHN`. However, the challenge state is emitted briefly before the auto-response (line ~1281: `emit(challengeState)`).

**Options:**
1. Map `ChallengeNameType.webAuthn` to a transient step like `AuthSignInStep.done` -- problematic, implies sign-in is complete.
2. Map to `AuthSignInStep.confirmSignInWithCustomChallenge` -- misleading.
3. Keep throwing but ensure the challenge state emission is skipped for auto-responding challenges.
4. Add a new `AuthSignInStep` value -- invasive.

**Recommended approach:** Since `createRespondToAuthChallengeRequest` returns a non-null request for `webAuthn` (auto-respond), the `challengeState` is emitted at line 1281 before `_respondToChallenge`. The `signInStep` getter is called during challenge state construction. We should map `ChallengeNameType.webAuthn` to a reasonable value or handle it specially. Looking at the code flow: `challengeState` uses `_challengeName!.signInStep` only in the `SignInChallenge` constructor path. Since `webAuthn` auto-responds, this emitted state is transient (immediately replaced by the next state). We can map it to a new or existing step that signals "processing in progress." The safest approach is to define a clear mapping -- perhaps `AuthSignInStep.confirmSignInWithCustomChallenge` as a temporary transient state, or more accurately, just let it map to something benign. **Best choice: skip the `signInStep` call entirely for auto-responding challenges, or map `webAuthn` to a dedicated value.** In practice, mapping to a value that the plugin layer can handle is simplest.

### Risk 3: Platform Bridge Not Registered

If `WebAuthnCredentialPlatform` is not registered in the dependency manager (e.g., on a platform where passkeys are not supported, or the Flutter wrapper hasn't registered it yet), calling `get<WebAuthnCredentialPlatform>()` returns null.

**Mitigation:** Check for null before attempting the ceremony and throw `PasskeyNotSupportedException` with a clear message.

### Risk 4: SELECT_CHALLENGE -> WEB_AUTHN Two-Step Flow

When user selects `WEB_AUTHN` via `confirmSignIn(challengeResponse: 'WEB_AUTHN')`, the existing `createSelectFirstFactorRequest()` sends `ANSWER: WEB_AUTHN` to Cognito. Cognito responds with a `WEB_AUTHN` challenge. The state machine then needs to auto-handle this second challenge. This works naturally IF the `webAuthn` case in `createRespondToAuthChallengeRequest` does NOT have a `when hasUserResponse` guard -- it will auto-respond on the recursive `_processChallenge()` call.

**Key insight:** The two-step flow works automatically if WEB_AUTHN handling is unconditional (no `hasUserResponse` guard).

### Risk 5: CREDENTIAL_REQUEST_OPTIONS Missing or Malformed

Cognito might return unexpected JSON format in `CREDENTIAL_REQUEST_OPTIONS`.

**Mitigation:** Wrap the JSON parse in a try-catch and throw `PasskeyAssertionFailedException` with the parse error details.

### Risk 6: Session Token Expiry During Platform Ceremony

The WebAuthn ceremony involves user interaction (biometric) which may take time. If the session token expires before the `RespondToAuthChallenge` call, Cognito will reject it.

**Mitigation:** Cognito sessions typically last 3 minutes, which should be sufficient. Document this limitation.

### Risk 7: Test Infrastructure

The existing `MockCognitoIdentityProviderClient` supports mocking `initiateAuth` and `respondToAuthChallenge`. For WEB_AUTHN tests, we also need a mock `WebAuthnCredentialPlatform`. This is straightforward to create.

---

## 8. Validation Architecture

### Unit Test Strategy

Tests should cover these scenarios using `MockCognitoIdentityProviderClient` and a mock `WebAuthnCredentialPlatform`:

#### Test 1: Direct WEB_AUTHN Challenge (FLOW-01)
- Mock `initiateAuth` to return `ChallengeName: WEB_AUTHN` with `CREDENTIAL_REQUEST_OPTIONS`
- Mock `WebAuthnCredentialPlatform.getCredential()` to return a valid assertion JSON
- Mock `respondToAuthChallenge` to return `AuthenticationResult` with tokens
- Verify sign-in completes successfully (state machine reaches `SignInSuccess`)
- Verify the `CREDENTIAL` key in the `respondToAuthChallenge` request body matches the platform bridge output

#### Test 2: SELECT_CHALLENGE with WEB_AUTHN Available (FLOW-02)
- Mock `initiateAuth` to return `ChallengeName: SELECT_CHALLENGE` with `AvailableChallenges: [WEB_AUTHN, PASSWORD]`
- Verify the state machine yields `SignInChallenge` with `allowedfirstFactorTypes` containing `AuthFactorType.webAuthn`
- Verify the `AuthSignInStep` is `continueSignInWithFirstFactorSelection`

#### Test 3: Two-Step WEB_AUTHN (SELECT_CHALLENGE -> WEB_AUTHN) (FLOW-03)
- Mock `initiateAuth` -> SELECT_CHALLENGE
- Dispatch `SignInRespondToChallenge(answer: 'WEB_AUTHN')`
- Mock first `respondToAuthChallenge` -> WEB_AUTHN challenge with CREDENTIAL_REQUEST_OPTIONS
- Mock `WebAuthnCredentialPlatform.getCredential()` -> assertion JSON
- Mock second `respondToAuthChallenge` -> AuthenticationResult
- Verify complete flow from SELECT -> ceremony -> success

#### Test 4: Platform Bridge Cancellation
- Mock `WebAuthnCredentialPlatform.getCredential()` to throw `PasskeyCancelledException`
- Verify state machine emits `SignInFailure` with `PasskeyCancelledException`

#### Test 5: Platform Bridge Not Available
- Do not register `WebAuthnCredentialPlatform` in dependency manager
- Initiate sign-in that triggers WEB_AUTHN challenge
- Verify `PasskeyNotSupportedException` is thrown

#### Test 6: Malformed CREDENTIAL_REQUEST_OPTIONS
- Mock `initiateAuth` to return WEB_AUTHN challenge with invalid JSON in CREDENTIAL_REQUEST_OPTIONS
- Verify appropriate error is thrown

### Integration Test Considerations

Full integration testing requires:
1. A Cognito user pool with passkeys enabled
2. A real platform bridge implementation (Phase 3)
3. A device capable of WebAuthn ceremonies

This cannot be tested end-to-end until Phase 3 platform bridges are built. Phase 2 validation relies on unit tests with mocks.

### Static Analysis Verification

```bash
dart analyze packages/amplify_core
dart analyze packages/auth/amplify_auth_cognito_dart
dart analyze packages/auth/amplify_auth_cognito
dart analyze packages/auth/amplify_auth_cognito_test
```

### Test Execution

```bash
cd packages/auth/amplify_auth_cognito_test
dart test test/state/sign_in_webauthn_test.dart
```

### Regression Safety

All existing sign-in tests must continue to pass. The changes are additive (new case in switch statement) and should not affect existing challenge flows.

---

## 9. Implementation Design Summary

### Core Change: Add WEB_AUTHN to createRespondToAuthChallengeRequest()

```dart
// In the switch statement, add BEFORE the wildcard:
ChallengeNameType.webAuthn => createWebAuthnAssertionRequest(challengeParameters),
```

Note: NO `when hasUserResponse` guard -- this is an auto-responding challenge.

### New Method: createWebAuthnAssertionRequest()

```dart
@protected
Future<RespondToAuthChallengeRequest> createWebAuthnAssertionRequest(
  BuiltMap<String, String?> challengeParameters,
) async {
  final optionsJson = challengeParameters[CognitoConstants.challengeParamCredentialRequestOptions];
  if (optionsJson == null || optionsJson.isEmpty) {
    throw const PasskeyAssertionFailedException(
      'CREDENTIAL_REQUEST_OPTIONS not found in challenge parameters',
    );
  }

  final platform = get<WebAuthnCredentialPlatform>();
  if (platform == null) {
    throw const PasskeyNotSupportedException(
      'No WebAuthn platform bridge is registered. '
      'Ensure passkey support is configured for this platform.',
    );
  }

  final credentialJson = await platform.getCredential(optionsJson);

  return RespondToAuthChallengeRequest.build((b) {
    b
      ..challengeName = ChallengeNameType.webAuthn
      ..challengeResponses.addAll({
        CognitoConstants.challengeParamUsername: cognitoUsername,
        CognitoConstants.challengeParamCredential: credentialJson,
      })
      ..clientId = _authOutputs.userPoolClientId;
  });
}
```

### SDK Bridge Update

Replace the `InvalidStateException` with a valid `AuthSignInStep`:

```dart
ChallengeNameType.webAuthn => AuthSignInStep.confirmSignInWithCustomChallenge,
// This is transient -- the WEB_AUTHN challenge auto-responds so this step
// is only briefly visible if the UI observes the intermediate state.
```

Alternatively, if a more specific step is warranted, it could map to a new value -- but adding enum values is invasive and affects amplify_core. Using `confirmSignInWithCustomChallenge` as a transient marker is pragmatic.

### Constants Addition

```dart
/// The `CREDENTIAL_REQUEST_OPTIONS` parameter.
static const challengeParamCredentialRequestOptions = 'CREDENTIAL_REQUEST_OPTIONS';

/// The `CREDENTIAL` parameter.
static const challengeParamCredential = 'CREDENTIAL';
```

---

*Research completed: 2026-03-07*

# Phase 3: WebAuthn Sign-In Ceremony — Implementation Plan

## Overview

Wire the WEB_AUTHN challenge into the sign-in state machine so that when Cognito returns a `WEB_AUTHN` challenge (either directly or via `SELECT_CHALLENGE`), the state machine automatically invokes the platform bridge to perform the passkey assertion ceremony, sends the result back to Cognito, and completes sign-in.

## Design Decisions (from discussion)

| Decision | Choice |
|---|---|
| Ceremony trigger | Fully automatic — state machine handles WEB_AUTHN end-to-end |
| Timeout | Defer to platform's native timeout |
| Bridge call location | Inline in `resolve()` |
| Cancellation | Keep session alive, surface retriable step (retry in-place) |
| Bridge injection | `DependencyManager.addBuilder<PasskeyPlatform>()` |
| Missing bridge | Throw `InvalidStateException` |
| Challenge routing | New `ChallengeNameType.webAuthn` switch case |
| SELECT_CHALLENGE | Include `webAuthn` in factor list |
| Error mapping | Typed `PasskeyException` subtypes |
| Android quirks | Document only, native bridge normalizes |

## Implementation Steps

### Step 1: Add `ChallengeNameType.webAuthn`

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_exception.dart` (or wherever ChallengeNameType is defined — it's from the Cognito SDK, may need to check if it's already available in the generated SDK types)

- Verify that `ChallengeNameType.webAuthn` exists in the Cognito SDK package. If not, we need to check the SDK version or add it.

### Step 2: Add `AuthFactorType.webAuthn` enum value

**File:** `packages/auth/amplify_auth_cognito/lib/src/model/sign_in/auth_factor_type.dart` (or similar)

- Add `webAuthn` to `AuthFactorType` enum if not already present
- Map it to/from the Cognito SDK's challenge name

### Step 3: Register `PasskeyPlatform` via DependencyManager

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart`

- In `configure()`, add: `_stateMachine.addBuilder<PasskeyPlatform>(_passkeyPlatformFactory)`
- Accept an optional `PasskeyPlatform Function()?` in the plugin constructor
- Default factory returns the `PasskeyPlatform.instance` (from Phase 2's federated plugin)

**File:** `packages/auth/amplify_auth_cognito/lib/src/amplify_auth_cognito.dart` (Flutter wrapper)

- Override factory to provide the real platform implementation

### Step 4: Add WEB_AUTHN case to `_respondToChallenge`

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

Add a new case in the switch:

```dart
ChallengeNameType.webAuthn => _handleWebAuthnChallenge(
  challengeParameters,
  session,
),
```

Implement `_handleWebAuthnChallenge()`:
1. Get `PasskeyPlatform` from `getOrCreate()` — throw `InvalidStateException` if not registered
2. Parse `CREDENTIAL_REQUEST_OPTIONS` from `challengeParameters`
3. Call `passkeyPlatform.getCredential(credentialRequestOptions)`
4. On success: build `RespondToAuthChallengeRequest` with the credential JSON
5. On `PasskeyCancelledException`: surface retriable state (see Step 6)
6. On other `PasskeyException` subtypes: rethrow (will be caught by state machine error handling)

### Step 5: Wire WEB_AUTHN into SELECT_CHALLENGE factor list

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

In the `selectChallenge` handling code:
- Parse `AVAILABLE_CHALLENGES` string (comma-separated)
- Map `WEB_AUTHN` to `AuthFactorType.webAuthn`
- Include it in the `allowedFactors` set for `continueSignInWithFirstFactorSelection`

When user calls `confirmSignIn(challengeResponse: 'WEB_AUTHN')`:
- State machine sends `RespondToAuthChallenge` selecting WEB_AUTHN
- Cognito responds with WEB_AUTHN challenge containing `CREDENTIAL_REQUEST_OPTIONS`
- Falls into the Step 4 handler automatically

### Step 6: Handle cancellation with retry-in-place

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

When `_handleWebAuthnChallenge` catches `PasskeyCancelledException`:
- Do NOT throw — instead return a `SignInState` with:
  - `signInStep: AuthSignInStep.confirmSignInWithWebAuthn` (new step enum value)
  - Preserve the Cognito session in state machine fields
- When caller calls `confirmSignIn()` again (with empty/null response), re-trigger the ceremony
- This allows the platform dialog to be shown again without restarting the flow

### Step 7: Add `AuthSignInStep.confirmSignInWithWebAuthn`

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/model/sign_in/cognito_sign_in_step.dart` (or wherever AuthSignInStep is defined)

- Add new enum value `confirmSignInWithWebAuthn`
- This signals to the caller that the passkey dialog was cancelled and they can retry by calling `confirmSignIn()`

### Step 8: Add typed PasskeyException subtypes

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/exception/passkey_exception.dart` (new file)

```dart
/// Base class for passkey-related exceptions.
sealed class PasskeyException extends AuthException {
  const PasskeyException(super.message, {super.recoverySuggestion, super.underlyingException});
}

class PasskeyCancelledException extends PasskeyException { ... }
class PasskeyNotSupportedException extends PasskeyException { ... }
class PasskeyNotAllowedException extends PasskeyException { ... }
class PasskeySecurityException extends PasskeyException { ... }
class PasskeyUnknownException extends PasskeyException { ... }
```

Export from the package's public API barrel file.

### Step 9: Build the RespondToAuthChallenge request for WEB_AUTHN

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

Create `_buildWebAuthnChallengeResponse()`:
- Takes the credential JSON from the platform bridge
- Builds `RespondToAuthChallengeRequest`:
  - `challengeName: ChallengeNameType.webAuthn`
  - `challengeResponses: { 'CREDENTIAL': credentialJson, 'USERNAME': cognitoUsername }`
  - `clientId: userPoolClientId`
  - `session: session`

### Step 10: Add USER_AUTH flow type support

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

In `_initiateAuth()` or equivalent:
- When `authFlowType == AuthenticationFlowType.userAuth`:
  - Use `AuthFlowType.userAuth` for the `InitiateAuth` call
  - If `preferredFirstFactor` is set, include it in auth parameters
- Handle the case where Cognito responds with `SELECT_CHALLENGE` (routes to Step 5)
- Handle the case where Cognito responds directly with `WEB_AUTHN` (routes to Step 4)

### Step 11: Unit tests

**File:** `packages/auth/amplify_auth_cognito_dart/test/state/machines/sign_in_state_machine_webauthn_test.dart` (new)

Test cases:
1. WEB_AUTHN challenge → auto-invokes bridge → completes sign-in
2. SELECT_CHALLENGE with WEB_AUTHN → user selects → auto-invokes → completes
3. Missing platform bridge → throws InvalidStateException
4. User cancels → returns confirmSignInWithWebAuthn step → retry succeeds
5. Platform returns notAllowed → throws PasskeyNotAllowedException
6. Platform returns notSupported → throws PasskeyNotSupportedException

**File:** `packages/auth/amplify_auth_cognito_dart/test/state/machines/sign_in_state_machine_webauthn_test.dart`

Use mock `PasskeyPlatform` registered via DependencyManager.

### Step 12: Integration test stubs

**File:** `packages/auth/amplify_auth_cognito/example/integration_test/webauthn_sign_in_test.dart` (new)

- Stub tests that verify the wiring from Flutter wrapper → state machine → mock bridge
- These run on device but use a mock Cognito backend

## File Change Summary

| File | Action | Description |
|---|---|---|
| `auth_plugin_impl.dart` | Edit | Register PasskeyPlatform via DependencyManager |
| `amplify_auth_cognito.dart` | Edit | Provide real PasskeyPlatform factory in Flutter wrapper |
| `sign_in_state_machine.dart` | Edit | Add WEB_AUTHN switch case, handle ceremony, retry logic |
| `cognito_sign_in_step.dart` (or equivalent) | Edit | Add `confirmSignInWithWebAuthn` step |
| `auth_factor_type.dart` (or equivalent) | Edit | Add `webAuthn` factor type |
| `passkey_exception.dart` | New | Typed PasskeyException hierarchy |
| `sign_in_state_machine_webauthn_test.dart` | New | Unit tests |
| `webauthn_sign_in_test.dart` | New | Integration test stubs |

## Dependencies

- **Phase 2 output:** `PasskeyPlatform` interface with `getCredential()` method and platform implementations
- **Cognito SDK:** Must support `ChallengeNameType.webAuthn` and `AuthFlowType.userAuth`

## Risk Areas

1. **Cognito SDK version:** The generated SDK types may not include `webAuthn` challenge type yet — may need to update SDK or use raw string values
2. **Credential JSON format:** The exact format Cognito expects for the `CREDENTIAL` challenge response needs verification against AWS docs
3. **Session expiry during retry:** If user takes too long to retry after cancellation, the Cognito session may expire — need graceful handling

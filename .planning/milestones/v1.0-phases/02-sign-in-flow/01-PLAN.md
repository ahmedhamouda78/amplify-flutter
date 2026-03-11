---
wave: 1
depends_on: []
files_modified:
  - packages/auth/amplify_auth_cognito_dart/lib/src/flows/constants.dart
  - packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart
requirements: [FLOW-02]
autonomous: true
---

# Plan 01: Add WebAuthn Constants and Update SDK Bridge

## Objective

Add the `CREDENTIAL_REQUEST_OPTIONS` and `CREDENTIAL` challenge parameter constants to `CognitoConstants`, and replace the Phase 1 `InvalidStateException` placeholder in `sdk_bridge.dart` with a proper `AuthSignInStep` mapping for `ChallengeNameType.webAuthn`.

## Tasks

### Task 1: Add WebAuthn challenge parameter constants

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/flows/constants.dart`

1. Add two new constants to the `CognitoConstants` class, following the existing `challengeParam*` naming pattern. Place them after the existing challenge parameter constants (after `challengeParamAnswer` / near the end of the challenge params section):
   ```dart
   /// The `CREDENTIAL_REQUEST_OPTIONS` challenge parameter.
   ///
   /// Contains JSON-serialized `PublicKeyCredentialRequestOptions` for WebAuthn
   /// assertion ceremonies.
   static const challengeParamCredentialRequestOptions =
       'CREDENTIAL_REQUEST_OPTIONS';

   /// The `CREDENTIAL` challenge response parameter.
   ///
   /// Contains JSON-serialized `AuthenticationResponseJSON` from the WebAuthn
   /// assertion ceremony.
   static const challengeParamCredential = 'CREDENTIAL';
   ```

### Task 2: Replace InvalidStateException with proper signInStep mapping

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart`

1. In the `ChallengeNameTypeBridge` extension's `signInStep` getter, replace the `ChallengeNameType.webAuthn` case (lines 41-45) that currently throws `InvalidStateException`:

   **Replace:**
   ```dart
   ChallengeNameType.webAuthn =>
     throw InvalidStateException(
       'WEB_AUTHN challenge requires platform WebAuthn bridge support. '
       'Ensure passkey support is configured.',
     ),
   ```

   **With:**
   ```dart
   ChallengeNameType.webAuthn =>
     AuthSignInStep.confirmSignInWithCustomChallenge,
   ```

   Note: WEB_AUTHN is an auto-responding challenge — the state machine handles it internally without yielding to the user. The `signInStep` is only briefly visible during the transient challenge state emission before auto-response. Using `confirmSignInWithCustomChallenge` is a pragmatic mapping for this transient state since adding a new `AuthSignInStep` enum value would be invasive across the `amplify_core` package.

2. Remove the `InvalidStateException` import if it was only used for this case. Check if `InvalidStateException` is imported from `package:amplify_core` — if other cases still use it, leave the import.

## Verification

1. `dart analyze packages/auth/amplify_auth_cognito_dart` — no errors
2. `CognitoConstants.challengeParamCredentialRequestOptions == 'CREDENTIAL_REQUEST_OPTIONS'`
3. `CognitoConstants.challengeParamCredential == 'CREDENTIAL'`
4. `ChallengeNameType.webAuthn.signInStep == AuthSignInStep.confirmSignInWithCustomChallenge` — no longer throws
5. Existing challenge mappings unchanged — no regressions

## must_haves

- [ ] `CognitoConstants.challengeParamCredentialRequestOptions` constant exists with value `'CREDENTIAL_REQUEST_OPTIONS'`
- [ ] `CognitoConstants.challengeParamCredential` constant exists with value `'CREDENTIAL'`
- [ ] `ChallengeNameType.webAuthn` case in `signInStep` no longer throws `InvalidStateException`
- [ ] `ChallengeNameType.webAuthn.signInStep` returns a valid `AuthSignInStep`
- [ ] No regressions in existing challenge-to-step mappings

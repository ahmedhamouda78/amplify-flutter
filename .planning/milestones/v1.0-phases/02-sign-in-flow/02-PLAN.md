---
wave: 1
depends_on: [01]
files_modified:
  - packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart
requirements: [FLOW-01, FLOW-03, AUTH-01]
autonomous: true
---

# Plan 02: Add WEB_AUTHN Challenge Handler to Sign-In State Machine

## Objective

Add WebAuthn assertion handling to the sign-in state machine so that `WEB_AUTHN` challenges from Cognito are automatically processed by calling the platform bridge's `getCredential()` method and responding with the serialized credential.

## Tasks

### Task 1: Add webAuthn case to createRespondToAuthChallengeRequest()

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

1. In the `createRespondToAuthChallengeRequest()` method's switch statement (around lines 348-390), add a case for `ChallengeNameType.webAuthn` BEFORE the wildcard `_` case.

   **Important:** This case must NOT have a `when hasUserResponse` guard — WEB_AUTHN is an auto-responding challenge (like `passwordVerifier` and `deviceSrpAuth`). The state machine handles it internally by calling the platform bridge, not by waiting for user text input.

   ```dart
   ChallengeNameType.webAuthn =>
     createWebAuthnAssertionRequest(challengeParameters),
   ```

### Task 2: Create the createWebAuthnAssertionRequest() method

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

1. Add a new method following the existing challenge handler pattern. Place it near the other `create*Request` methods (e.g., after `createSelectFirstFactorRequest` or at the end of the challenge handler methods section):

   ```dart
   /// Creates a [RespondToAuthChallengeRequest] for a WEB_AUTHN challenge
   /// by invoking the platform WebAuthn bridge to perform an assertion ceremony.
   @protected
   Future<RespondToAuthChallengeRequest> createWebAuthnAssertionRequest(
     BuiltMap<String, String?> challengeParameters,
   ) async {
     // 1. Extract CREDENTIAL_REQUEST_OPTIONS from challenge parameters
     final optionsJson = challengeParameters[
         CognitoConstants.challengeParamCredentialRequestOptions];
     if (optionsJson == null || optionsJson.isEmpty) {
       throw const PasskeyAssertionFailedException(
         'CREDENTIAL_REQUEST_OPTIONS not found in challenge parameters',
       );
     }

     // 2. Get the platform bridge from the dependency manager
     final platform = get<WebAuthnCredentialPlatform>();
     if (platform == null) {
       throw const PasskeyNotSupportedException(
         'No WebAuthn platform bridge is registered. '
         'Ensure passkey support is configured for this platform.',
       );
     }

     // 3. Perform the WebAuthn assertion ceremony via platform bridge
     final credentialJson = await platform.getCredential(optionsJson);

     // 4. Build the response
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

2. Add the necessary imports at the top of the file (if not already present):
   ```dart
   import 'package:amplify_auth_cognito_dart/src/model/webauthn/webauthn_credential_platform.dart';
   import 'package:amplify_core/src/types/exception/auth/passkey_exception.dart';
   ```

   Check the existing import pattern — the file may already import from the barrel export `package:amplify_auth_cognito_dart/amplify_auth_cognito_dart.dart` which re-exports these types. If so, no new imports needed.

### Task 3: Verify SELECT_CHALLENGE -> WEB_AUTHN two-step flow works

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart`

1. Review `createSelectFirstFactorRequest()` (lines 858-896) to confirm that when user selects `AuthFactorType.webAuthn`, the existing code sends `ANSWER: WEB_AUTHN` to Cognito correctly.

2. The existing code at line 887-895 builds a `RespondToAuthChallengeRequest` with `challengeParamAnswer: selectedFactor.value` for non-password factors. Since `AuthFactorType.webAuthn.value == 'WEB_AUTHN'`, this already sends `ANSWER: WEB_AUTHN` correctly. **No changes needed here.**

3. After Cognito responds with a `WEB_AUTHN` challenge, the state machine loops back through `_processChallenge()` which calls `createRespondToAuthChallengeRequest()` again. Since the webAuthn case has no `hasUserResponse` guard, it auto-responds — completing the two-step flow. **No changes needed in the flow logic.**

## Verification

1. `dart analyze packages/auth/amplify_auth_cognito_dart` — no errors
2. The `createRespondToAuthChallengeRequest` switch handles `ChallengeNameType.webAuthn` without requiring user input
3. `createWebAuthnAssertionRequest()` extracts `CREDENTIAL_REQUEST_OPTIONS`, calls `getCredential()`, and builds response with `CREDENTIAL`
4. Method throws `PasskeyAssertionFailedException` if `CREDENTIAL_REQUEST_OPTIONS` is missing
5. Method throws `PasskeyNotSupportedException` if `WebAuthnCredentialPlatform` is not registered
6. Two-step flow (SELECT_CHALLENGE -> WEB_AUTHN) works because webAuthn auto-responds on the recursive `_processChallenge()` call
7. Existing challenge handlers unchanged — no regressions

## must_haves

- [ ] `ChallengeNameType.webAuthn` case exists in `createRespondToAuthChallengeRequest()` switch without `when hasUserResponse` guard
- [ ] `createWebAuthnAssertionRequest()` method exists and follows the challenge handler pattern
- [ ] Method retrieves `WebAuthnCredentialPlatform` from dependency manager with null check
- [ ] Method extracts `CREDENTIAL_REQUEST_OPTIONS` from challenge parameters
- [ ] Method calls `platform.getCredential(optionsJson)` and sends result as `CREDENTIAL`
- [ ] `PasskeyNotSupportedException` thrown when platform bridge is not registered
- [ ] `PasskeyAssertionFailedException` thrown when `CREDENTIAL_REQUEST_OPTIONS` is missing
- [ ] SELECT_CHALLENGE -> WEB_AUTHN two-step flow works automatically (no additional code needed)
- [ ] No regressions in existing sign-in flows

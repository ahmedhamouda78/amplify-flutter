---
wave: 2
depends_on: [01, 02]
files_modified:
  - packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart
requirements: [FLOW-01, FLOW-02, FLOW-03, AUTH-01]
autonomous: true
---

# Plan 03: Unit Tests for WEB_AUTHN Sign-In Flow

## Objective

Create comprehensive unit tests that validate all WEB_AUTHN sign-in scenarios: direct challenge, SELECT_CHALLENGE with webAuthn available, two-step flow, and error cases. Tests use the existing mock infrastructure.

## Tasks

### Task 1: Create the test file with mock setup

**File:** `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart`

1. Create a new test file following the pattern from `sign_in_state_machine_test.dart`. Set up:

   - Import required packages:
     ```dart
     import 'package:amplify_auth_cognito_dart/amplify_auth_cognito_dart.dart';
     import 'package:amplify_auth_cognito_dart/src/flows/constants.dart';
     import 'package:amplify_auth_cognito_dart/src/model/webauthn/webauthn_credential_platform.dart';
     import 'package:amplify_auth_cognito_dart/src/state/state.dart';
     import 'package:amplify_core/amplify_core.dart';
     import 'package:amplify_secure_storage_dart/amplify_secure_storage_dart.dart';
     import 'package:test/test.dart';
     ```

   - Create a `MockWebAuthnCredentialPlatform` class implementing `WebAuthnCredentialPlatform`:
     ```dart
     class MockWebAuthnCredentialPlatform implements WebAuthnCredentialPlatform {
       final Future<String> Function(String optionsJson)? onGetCredential;
       final Future<String> Function(String optionsJson)? onCreateCredential;
       final bool Function()? onIsPasskeySupported;

       MockWebAuthnCredentialPlatform({
         this.onGetCredential,
         this.onCreateCredential,
         this.onIsPasskeySupported,
       });

       @override
       Future<String> getCredential(String optionsJson) =>
           onGetCredential!(optionsJson);

       @override
       Future<String> createCredential(String optionsJson) =>
           onCreateCredential!(optionsJson);

       @override
       bool isPasskeySupported() => onIsPasskeySupported?.call() ?? true;
     }
     ```

   - Create a helper method for common state machine setup that:
     - Creates `SecureStorageInterface` (in-memory)
     - Creates `CognitoAuthStateMachine`
     - Registers `SecureStorageInterface`
     - Registers mock `CognitoIdentityProviderClient`
     - Optionally registers `WebAuthnCredentialPlatform`
     - Returns the configured state machine

   - Define test constants:
     ```dart
     const testUsername = 'testuser';
     const testCredentialRequestOptions = '{"challenge":"dGVzdC1jaGFsbGVuZ2U","rpId":"example.com","allowCredentials":[],"timeout":60000,"userVerification":"preferred"}';
     const testCredentialResponse = '{"id":"credential-id","rawId":"Y3JlZGVudGlhbC1pZA","type":"public-key","response":{"clientDataJSON":"eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiZEdWemRDMWphR0ZzYkdWdVoyVSIsIm9yaWdpbiI6Imh0dHBzOi8vZXhhbXBsZS5jb20ifQ","authenticatorData":"SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MdAAAAAA","signature":"MEUCIQDKg7m-jRDKvPIzSaR6SYMBjG3qPLCvkKqz_Ypfhnkm3QIgF_1c2XHGhfR8bTQk6z0YVVy3E-6QFXT1GTf0C_3tzI","userHandle":"dXNlci1pZA"},"clientExtensionResults":{}}';
     ```

### Task 2: Test direct WEB_AUTHN challenge flow (FLOW-01, AUTH-01)

Add test: `'handles direct WEB_AUTHN challenge and completes sign-in'`

1. Mock `initiateAuth` to return:
   - `challengeName: ChallengeNameType.webAuthn`
   - `challengeParameters: { 'CREDENTIAL_REQUEST_OPTIONS': testCredentialRequestOptions, 'USERNAME': testUsername }`
   - `session: 'test-session'`

2. Mock `WebAuthnCredentialPlatform.getCredential()` to return `testCredentialResponse`

3. Mock `respondToAuthChallenge` to return:
   - `authenticationResult` with `accessToken`, `idToken`, `refreshToken`, `expiresIn`

4. Dispatch `SignInEvent.initiate(authFlowType: AuthFlowType.userAuth, parameters: { 'USERNAME': testUsername })`

5. Assert the state machine emits `SignInSuccess` (sign-in completes without user interaction)

6. Verify that `respondToAuthChallenge` was called with:
   - `challengeName: ChallengeNameType.webAuthn`
   - `challengeResponses` containing `USERNAME` and `CREDENTIAL` keys
   - The `CREDENTIAL` value matches `testCredentialResponse`

### Task 3: Test SELECT_CHALLENGE with webAuthn available (FLOW-02)

Add test: `'SELECT_CHALLENGE includes webAuthn in available factors'`

1. Mock `initiateAuth` to return:
   - `challengeName: ChallengeNameType.selectChallenge`
   - `availableChallenges: [ChallengeNameType.webAuthn, ChallengeNameType.password]`
   - `session: 'test-session'`

2. Dispatch sign-in initiate event

3. Assert the state machine emits `SignInChallenge` with:
   - `signInStep == AuthSignInStep.continueSignInWithFirstFactorSelection`
   - `allowedFirstFactorTypes` contains `AuthFactorType.webAuthn`
   - `allowedFirstFactorTypes` contains `AuthFactorType.password`

### Task 4: Test two-step SELECT_CHALLENGE -> WEB_AUTHN flow (FLOW-03)

Add test: `'completes two-step SELECT_CHALLENGE -> WEB_AUTHN flow'`

1. Mock `initiateAuth` -> SELECT_CHALLENGE with available challenges `[WEB_AUTHN, PASSWORD]`

2. Mock first `respondToAuthChallenge` (for SELECT_CHALLENGE answer) -> returns WEB_AUTHN challenge with `CREDENTIAL_REQUEST_OPTIONS`

3. Mock `WebAuthnCredentialPlatform.getCredential()` -> returns `testCredentialResponse`

4. Mock second `respondToAuthChallenge` (for WEB_AUTHN response) -> returns `authenticationResult` with tokens

5. Dispatch sign-in initiate. Wait for `SignInChallenge` state.

6. Dispatch `SignInRespondToChallenge(answer: 'WEB_AUTHN')`

7. Assert the state machine eventually emits `SignInSuccess`

### Task 5: Test platform bridge cancellation

Add test: `'emits failure when user cancels WebAuthn ceremony'`

1. Mock `initiateAuth` -> WEB_AUTHN challenge with CREDENTIAL_REQUEST_OPTIONS
2. Mock `WebAuthnCredentialPlatform.getCredential()` to throw `PasskeyCancelledException('User cancelled')`
3. Dispatch sign-in
4. Assert `SignInFailure` is emitted with exception type `PasskeyCancelledException`

### Task 6: Test platform bridge not registered

Add test: `'emits failure when WebAuthn platform is not registered'`

1. Set up state machine WITHOUT registering `WebAuthnCredentialPlatform`
2. Mock `initiateAuth` -> WEB_AUTHN challenge with CREDENTIAL_REQUEST_OPTIONS
3. Dispatch sign-in
4. Assert `SignInFailure` is emitted with exception type `PasskeyNotSupportedException`

### Task 7: Test missing CREDENTIAL_REQUEST_OPTIONS

Add test: `'emits failure when CREDENTIAL_REQUEST_OPTIONS is missing'`

1. Mock `initiateAuth` -> WEB_AUTHN challenge WITHOUT `CREDENTIAL_REQUEST_OPTIONS` in challenge parameters
2. Register mock `WebAuthnCredentialPlatform`
3. Dispatch sign-in
4. Assert `SignInFailure` is emitted with exception type `PasskeyAssertionFailedException`

## Verification

1. `dart analyze packages/auth/amplify_auth_cognito_test` — no errors
2. `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` — all tests pass
3. Existing sign-in tests still pass: `dart test test/state/sign_in_state_machine_test.dart`
4. Test coverage:
   - Direct WEB_AUTHN challenge -> success (FLOW-01, AUTH-01)
   - SELECT_CHALLENGE with webAuthn in available factors (FLOW-02)
   - Two-step SELECT_CHALLENGE -> WEB_AUTHN -> success (FLOW-03)
   - Platform bridge cancellation -> failure
   - Platform bridge not registered -> failure
   - Missing CREDENTIAL_REQUEST_OPTIONS -> failure

## must_haves

- [ ] Test file compiles and all tests pass
- [ ] Direct WEB_AUTHN challenge completes sign-in without user interaction
- [ ] SELECT_CHALLENGE shows `AuthFactorType.webAuthn` in available factors
- [ ] Two-step flow (SELECT_CHALLENGE -> select WEB_AUTHN -> ceremony -> success) works end-to-end
- [ ] `PasskeyCancelledException` propagates correctly from platform bridge
- [ ] `PasskeyNotSupportedException` thrown when platform bridge is not registered
- [ ] `PasskeyAssertionFailedException` thrown for missing CREDENTIAL_REQUEST_OPTIONS
- [ ] Existing sign-in tests are unaffected

---
wave: 1
depends_on: []
files_modified:
  - packages/amplify_core/lib/src/types/auth/sign_in/auth_factor_type.dart
  - packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart
requirements: [FLOW-04]
autonomous: true
---

# Plan 01: Uncomment and Enable AuthFactorType.webAuthn

## Objective

Uncomment the `AuthFactorType.webAuthn` enum value so it is fully functional in the type system, and update the SDK bridge to handle the `ChallengeNameType.webAuthn` challenge type.

## Tasks

### Task 1: Uncomment webAuthn in AuthFactorType enum

**File:** `packages/amplify_core/lib/src/types/auth/sign_in/auth_factor_type.dart`

1. Remove the TODO comment block (lines 28-33) containing `// TODO(cadivus): Implement Passwordless Authenticator.` and the commented-out code.
2. Change the semicolon on `smsOtp('SMS_OTP');` (line 26) to a comma: `smsOtp('SMS_OTP'),`.
3. Add the uncommented enum value as the last entry before the semicolon:
   ```dart
   /// Sign in with WebAuthn (i.e. Passkey)
   @JsonValue('WEB_AUTHN')
   webAuthn('WEB_AUTHN');
   ```

### Task 2: Add webAuthn handling in ChallengeNameTypeBridge

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart`

1. In the `ChallengeNameTypeBridge` extension's `signInStep` getter (line 23), add a case for `ChallengeNameType.webAuthn` before the wildcard `_` case. Map it to throw an `InvalidStateException` with a descriptive message. This is a temporary placeholder that Phase 2 will replace with actual WEB_AUTHN challenge handling:
   ```dart
   ChallengeNameType.webAuthn =>
     throw InvalidStateException(
       'WEB_AUTHN challenge requires platform WebAuthn bridge support. '
       'Ensure passkey support is configured.',
     ),
   ```
2. The existing `_allowedFirstFactorTypes` getter in `sign_in_state_machine.dart` (line 234) already maps `availableChallenges` to `AuthFactorType` values by matching `factor.value == type.value`. Once `webAuthn` is uncommented, `ChallengeNameType.webAuthn` will automatically resolve to `AuthFactorType.webAuthn` in the allowed first factor types. No changes needed there.

## Verification

1. `dart analyze packages/amplify_core` -- no errors related to `AuthFactorType`
2. `dart analyze packages/auth/amplify_auth_cognito_dart` -- no errors related to the bridge
3. `AuthFactorType.webAuthn` is accessible and `AuthFactorType.webAuthn.value == 'WEB_AUTHN'`
4. `AuthFactorType.values` contains `webAuthn` (length increases from 4 to 5)
5. The `_allowedFirstFactorTypes` getter in `sign_in_state_machine.dart` will now include `AuthFactorType.webAuthn` when `ChallengeNameType.webAuthn` appears in `availableChallenges`
6. Existing tests continue to pass -- no regressions from adding a new enum value

## must_haves

- [ ] `AuthFactorType.webAuthn` enum value is uncommented and compiles
- [ ] `AuthFactorType.webAuthn.value == 'WEB_AUTHN'`
- [ ] `@JsonValue('WEB_AUTHN')` annotation is present for correct JSON serialization
- [ ] The TODO comment referencing `cadivus` is removed
- [ ] `ChallengeNameType.webAuthn` does not fall through to the catch-all error case in `sdk_bridge.dart`
- [ ] No regressions in existing `AuthFactorType` values or sign-in flows

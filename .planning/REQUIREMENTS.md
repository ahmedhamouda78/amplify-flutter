# Milestone v1.0: Passkey Support — Requirements

## Core Auth Plugin APIs

- [ ] **AUTH-01**: User can sign in with a passkey as primary first-factor via `signIn()` with `authFlowType: AuthenticationFlowType.userAuth` and `preferredFirstFactor: AuthFactorType.webAuthn`
- [ ] **AUTH-02**: User can register a new passkey on their account (post-authentication) via `associateWebAuthnCredential()` which calls `StartWebAuthnRegistration`, triggers platform ceremony, and calls `CompleteWebAuthnRegistration`
- [ ] **AUTH-03**: User can list their registered passkeys via `listWebAuthnCredentials()` returning credential ID, friendly name, relying party ID, authenticator attachment, transports, and creation date
- [ ] **AUTH-04**: User can delete a registered passkey via `deleteWebAuthnCredential(credentialId)` which calls Cognito `DeleteWebAuthnCredential`
- [ ] **AUTH-05**: User can check if the current platform supports passkeys via `isPasskeySupported()` returning a boolean
- [x] **AUTH-06**: User receives typed `AuthException` subtypes for passkey errors (not supported, user cancelled, registration failed, assertion failed, RP mismatch)

## State Machine & Sign-In Flow

- [ ] **FLOW-01**: Sign-in state machine handles `WEB_AUTHN` challenge by parsing `CREDENTIAL_REQUEST_OPTIONS` from challenge parameters, calling platform bridge for assertion, and responding to Cognito with serialized credential
- [ ] **FLOW-02**: Sign-in state machine handles `SELECT_CHALLENGE` response containing `WEB_AUTHN` in `availableChallenges`, returning `AuthSignInStep.continueSignInWithFirstFactorSelection` with available factors including `AuthFactorType.webAuthn`
- [ ] **FLOW-03**: User can select `WEB_AUTHN` via `confirmSignIn(challengeResponse: 'WEB_AUTHN')` which sends `ANSWER: WEB_AUTHN` to Cognito, receives `WEB_AUTHN` challenge with `CREDENTIAL_REQUEST_OPTIONS`, performs ceremony, and completes sign-in
- [x] **FLOW-04**: `AuthFactorType.webAuthn` enum value is uncommented and fully functional in the type system (currently has TODO comment)
- [ ] **FLOW-05**: WebAuthn serialization layer correctly converts between Cognito JSON format (base64url strings) and platform-specific WebAuthn types for both registration and assertion ceremonies

## Platform Bridges

- [ ] **PLAT-01**: iOS platform bridge wraps `ASAuthorizationPlatformPublicKeyCredentialProvider` / `ASAuthorizationController` for both `createCredential` and `getCredential` operations (iOS 17.4+)
- [ ] **PLAT-02**: Android platform bridge wraps `androidx.credentials.CredentialManager` for both `CreatePublicKeyCredentialRequest` and `GetPublicKeyCredentialOption` operations (API 28+)
- [ ] **PLAT-03**: macOS platform bridge shares the iOS/Darwin `ASAuthorizationController` implementation for both credential operations (macOS 13.5+)
- [ ] **PLAT-04**: Web platform bridge calls `navigator.credentials.create()` and `navigator.credentials.get()` via `dart:js_interop` for WebAuthn ceremonies
- [ ] **PLAT-05**: Windows platform bridge wraps Windows Hello / FIDO2 APIs via `windows_webauthn` FFI bindings for credential creation and assertion
- [ ] **PLAT-06**: Linux platform bridge provides best-effort passkey support via `libfido2` FFI bindings or returns `isPasskeySupported() = false` with graceful fallback if no FIDO2 authenticator is available
- [x] **PLAT-07**: Each platform bridge implements a minimal interface: `createCredential(String optionsJson) -> String responseJson`, `getCredential(String optionsJson) -> String responseJson`, `isPasskeySupported() -> bool`
- [ ] **PLAT-08**: Platform bridges map platform-specific errors (ASAuthorizationError, CredentialManager exceptions, DOMException, Windows/Linux errors) to typed Amplify `AuthException` subtypes

## Authenticator UI

- [ ] **UI-01**: Authenticator shows a challenge selection screen when `AuthSignInStep.continueSignInWithFirstFactorSelection` is returned, listing available factors (including passkey) for user selection
- [ ] **UI-02**: Authenticator handles passkey sign-in flow end-to-end: user selects passkey → platform ceremony triggers automatically → sign-in completes or error is shown
- [ ] **UI-03**: Authenticator optionally prompts user to register a passkey after successful sign-in/sign-up (configurable via `passwordless` options)
- [ ] **UI-04**: Authenticator displays user-friendly error messages when passkey operations fail (not supported, cancelled, failed) with appropriate recovery suggestions

## Future Requirements (Deferred)

- Passkey management UI in Authenticator (list/delete passkeys)
- Passkey as MFA factor
- Hosted UI passkey flows

## Out of Scope

- Custom authenticator themes for passkey UI — use existing theming system
- Cross-device passkey sync — handled by platform (iCloud Keychain, Google Password Manager)
- Passkey backup/recovery — platform responsibility
- Discoverable credential (usernameless) sign-in — requires UI changes beyond current scope

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | 2 | Pending |
| AUTH-02 | 5 | Pending |
| AUTH-03 | 5 | Pending |
| AUTH-04 | 5 | Pending |
| AUTH-05 | 5 | Pending |
| AUTH-06 | 1 | Complete |
| FLOW-01 | 2 | Pending |
| FLOW-02 | 2 | Pending |
| FLOW-03 | 2 | Pending |
| FLOW-04 | 1 | Complete |
| FLOW-05 | 1 | Pending |
| PLAT-01 | 3 | Pending |
| PLAT-02 | 3 | Pending |
| PLAT-03 | 4 | Pending |
| PLAT-04 | 3 | Pending |
| PLAT-05 | 4 | Pending |
| PLAT-06 | 4 | Pending |
| PLAT-07 | 1 | Complete |
| PLAT-08 | 3, 4 | Pending |
| UI-01 | 6 | Pending |
| UI-02 | 6 | Pending |
| UI-03 | 6 | Pending |
| UI-04 | 6 | Pending |

---
*Requirements defined: 2026-03-07*

# Amplify Flutter Passkey Support

## What This Is

Adding WebAuthn/passkey support to the amplify-flutter SDK, enabling passwordless primary sign-in and passkey registration across all six supported platforms (iOS, Android, macOS, Windows, Linux, Web). This spans both the low-level `amplify_auth_cognito` plugin APIs and the pre-built `amplify_authenticator` UI components.

## Core Value

Users can sign in with passkeys as a primary authentication factor on any platform supported by amplify-flutter, matching the passkey capabilities already available in amplify-js, amplify-swift, and amplify-android.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] WebAuthn credential registration (enrollment) flow via Cognito
- [ ] WebAuthn credential assertion (sign-in) flow as primary first-factor
- [ ] Platform bridge for iOS (Face ID / Touch ID via ASAuthorizationController)
- [ ] Platform bridge for Android (BiometricPrompt + Credential Manager)
- [ ] Platform bridge for macOS (shared Darwin implementation with iOS)
- [ ] Platform bridge for Web (navigator.credentials API via JS interop)
- [ ] Platform bridge for Windows (Windows Hello / FIDO2 APIs)
- [ ] Platform bridge for Linux (libfido2 or best-effort with fallback)
- [ ] `webAuthn` variant in `AuthFactorType` enum (currently commented out)
- [ ] Sign-in state machine support for `WEB_AUTHN` challenge type
- [ ] `continueSignInWithFirstFactorSelection` handling in Authenticator bloc
- [ ] Authenticator UI screens for passkey sign-in and registration
- [ ] Graceful fallback when passkeys are unavailable on a platform

### Out of Scope

- Passkey as MFA factor — only primary sign-in; reduces complexity, matches user request
- Hosted UI passkey flows — only native/in-app flows
- Custom authenticator themes for passkey UI — use existing Authenticator theming system
- Passkey management UI (delete/rename passkeys) — separate concern, not part of sign-in flow

## Context

- **Existing SDK support**: The Cognito SDK (Smithy-generated) already includes `WEB_AUTHN` as a `ChallengeNameType` and documents credential challenge/response handling
- **Explicit TODOs**: `auth_factor_type.dart` and `amplify_auth_service.dart` contain TODO comments with AWS doc links for passkey implementation
- **Current error**: The Authenticator bloc throws `"Passwordless is not supported at this time."` for unimplemented steps like `continueSignInWithFirstFactorSelection`
- **Reference implementations**: amplify-js (with amplify-ui), amplify-swift, and amplify-android all have shipping passkey support
- **Architecture**: Dual-package pattern — pure Dart core (`amplify_auth_cognito_dart`) + Flutter wrapper with Pigeon bridges (`amplify_auth_cognito`)
- **Platform split**: iOS/Android/macOS use Pigeon→native bridges; Windows/Linux use pure Dart; Web uses JS interop

## Constraints

- **Tech stack**: Must follow existing Pigeon-based platform bridge pattern for iOS/Android/macOS
- **Compatibility**: Must work with existing Cognito user pool configurations that enable passkeys
- **Architecture**: WebAuthn logic in pure Dart core where possible; platform-specific credential API calls via Pigeon bridges
- **API consistency**: Must align with existing `AuthSignInStep`, `AuthFactorType`, and `SignInResult` patterns
- **Security**: Passkey credentials must use platform-secure storage (Keychain, Keystore, Windows Hello, etc.)

## Current Milestone: v1.0 Passkey Support

**Goal:** Add WebAuthn/passkey support to amplify-flutter SDK for passwordless primary sign-in and credential management across iOS, Android, macOS, Web (with best-effort Windows/Linux).

**Target features:**
- WebAuthn sign-in flow (USER_AUTH + WEB_AUTHN challenge)
- Passkey credential registration (post-auth enrollment)
- Credential management APIs (list, delete)
- Platform bridges for iOS, Android, macOS, Web
- Authenticator UI integration for passkey flows

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Primary sign-in only, not MFA | Reduces scope; matches reference implementations' initial rollout | Locked |
| iOS/Android/macOS/Web first, Windows/Linux best-effort | Core platforms first; Windows/Linux have limited WebAuthn support | Locked |
| Full stack (plugin + UI) | Complete developer experience matching other Amplify SDKs | Locked |
| Follow Pigeon bridge pattern | Consistency with existing platform interop architecture | Locked |
| Cognito API calls via raw HTTP, not Smithy codegen | WebAuthn APIs (Start/Complete Registration, List/Delete Credentials) not in existing Smithy model; raw HTTP is faster to implement | Locked |
| Minimal method channel interface | Only `createCredential`, `getCredential`, `isPasskeySupported` cross the platform boundary; all Cognito logic stays in Dart | Locked |

---
*Last updated: 2026-03-07 after milestone v1.0 initialization*

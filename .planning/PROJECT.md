# Amplify Flutter Passkey Support

## What This Is

WebAuthn/passkey support for the amplify-flutter SDK, enabling passwordless primary sign-in, passkey registration, and credential management across all six supported platforms (iOS, Android, macOS, Windows, Linux, Web). Includes both the low-level `amplify_auth_cognito` plugin APIs and the pre-built `amplify_authenticator` UI components.

## Core Value

Users can sign in with passkeys as a primary authentication factor on any platform supported by amplify-flutter, matching the passkey capabilities already available in amplify-js, amplify-swift, and amplify-android.

## Requirements

### Validated

- WebAuthn credential registration (enrollment) flow via Cognito -- v1.0
- WebAuthn credential assertion (sign-in) flow as primary first-factor -- v1.0
- Platform bridge for iOS (Face ID / Touch ID via ASAuthorizationController) -- v1.0
- Platform bridge for Android (CredentialManager) -- v1.0
- Platform bridge for macOS (shared Darwin implementation with iOS) -- v1.0
- Platform bridge for Web (navigator.credentials API via JS interop) -- v1.0
- Platform bridge for Windows (Windows Hello / FIDO2 APIs via FFI) -- v1.0
- Platform bridge for Linux (libfido2 FFI with graceful fallback) -- v1.0
- `webAuthn` variant in `AuthFactorType` enum -- v1.0
- Sign-in state machine support for `WEB_AUTHN` challenge type -- v1.0
- `continueSignInWithFirstFactorSelection` handling in Authenticator bloc -- v1.0
- Authenticator UI screens for passkey sign-in and registration -- v1.0
- Graceful fallback when passkeys are unavailable on a platform -- v1.0

### Active

(None -- start next milestone to define new requirements)

### Out of Scope

- Passkey as MFA factor -- only primary sign-in; reduces complexity, matches reference implementations
- Hosted UI passkey flows -- only native/in-app flows
- Custom authenticator themes for passkey UI -- use existing Authenticator theming system
- Passkey management UI (delete/rename passkeys) -- separate concern, not part of sign-in flow
- Discoverable credential (usernameless) sign-in -- requires UI changes beyond current scope

## Context

Shipped v1.0 with 24,321 LOC across 153 files. 93 tests passing.

**Tech stack:** Dart/Flutter, Pigeon (iOS/Android/macOS bridges), dart:ffi (Windows/Linux), dart:js_interop (Web), AWS JSON 1.1 raw HTTP (Cognito WebAuthn operations).

**Architecture:** Dual-package pattern -- pure Dart core (`amplify_auth_cognito_dart`) + Flutter wrapper with Pigeon bridges (`amplify_auth_cognito`). iOS/Android/macOS use Pigeon native bridges; Windows/Linux use pure Dart FFI; Web uses JS interop.

**Platform support:**
- iOS 17.4+ (ASAuthorizationController)
- Android API 28+ (CredentialManager with Play Services fallback)
- macOS 13.5+ (shared Darwin implementation)
- Web (navigator.credentials via dart:js_interop)
- Windows (Windows Hello via webauthn.dll FFI, API v4+ JSON pass-through)
- Linux (libfido2 FFI, graceful fallback if unavailable)

## Current State

**Shipped:** v1.0 Passkey Support (2026-03-11)
**Next:** Planning next milestone (run `/gsd:new-milestone`)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Primary sign-in only, not MFA | Reduces scope; matches reference implementations' initial rollout | Good -- clean scope, all 23 requirements met |
| All 6 platforms including Windows/Linux | Complete coverage matching Flutter platform support | Good -- Windows Hello + libfido2 working |
| Full stack (plugin + UI) | Complete developer experience matching other Amplify SDKs | Good -- Authenticator fully integrated |
| Follow Pigeon bridge pattern | Consistency with existing platform interop architecture | Good -- iOS/Android/macOS via Pigeon |
| Cognito API calls via raw HTTP | WebAuthn APIs not in existing Smithy model | Good -- 4 operations working reliably |
| Minimal method channel interface | Only 3 methods cross platform boundary; all Cognito logic stays in Dart | Good -- clean separation |
| JSON string platform boundary | Keep serialization in Dart layer, platform bridges pass raw JSON | Good -- simplified bridge implementations |
| PasskeyException extends AuthException | Typed hierarchy with recovery suggestions | Good -- consistent error handling |
| Windows FFI raw pointer offsets | Avoid full Struct subclasses for version-dependent Windows structs | Good -- simpler FFI bindings |
| Linux libfido2 with graceful fallback | Best-effort support; returns isPasskeySupported=false if unavailable | Good -- no hard dependency |

## Constraints

- **Tech stack**: Must follow existing Pigeon-based platform bridge pattern for iOS/Android/macOS
- **Compatibility**: Must work with existing Cognito user pool configurations that enable passkeys
- **Architecture**: WebAuthn logic in pure Dart core where possible; platform-specific credential API calls via Pigeon bridges
- **API consistency**: Must align with existing `AuthSignInStep`, `AuthFactorType`, and `SignInResult` patterns
- **Security**: Passkey credentials must use platform-secure storage (Keychain, Keystore, Windows Hello, etc.)

---
*Last updated: 2026-03-11 after v1.0 milestone completion*

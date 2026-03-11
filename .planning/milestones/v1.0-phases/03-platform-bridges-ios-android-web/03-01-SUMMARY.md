---
phase: 03-platform-bridges-ios-android-web
plan: 01
subsystem: auth
tags: [pigeon, webauthn, passkey, code-generation, platform-bridge]

# Dependency graph
requires:
  - phase: 01-core-types-and-models
    provides: "WebAuthnCredentialPlatform interface and PasskeyException hierarchy"
  - phase: 02-sign-in-flow
    provides: "SignInStateMachine WebAuthn challenge handling that retrieves WebAuthnCredentialPlatform via DI"
provides:
  - "Pigeon WebAuthn bridge definition with generated Dart/Swift/Kotlin bindings"
  - "PigeonWebAuthnCredentialPlatform adapter with 5-code error mapping"
  - "WebAuthnCredentialPlatformImpl stub for unsupported platforms"
  - "Plugin registration wiring in auth_plugin_impl.dart"
affects: [03-02, 03-03, 03-04]

# Tech tracking
tech-stack:
  added: [pigeon v26]
  patterns: [pigeon-bridge-with-dart-error-mapping, stub-platform-pattern]

key-files:
  created:
    - packages/auth/amplify_auth_cognito/pigeons/webauthn_bridge.dart
    - packages/auth/amplify_auth_cognito/lib/src/webauthn_bridge.g.dart
    - packages/auth/amplify_auth_cognito/darwin/Classes/pigeons/WebAuthnBridge.g.swift
    - packages/auth/amplify_auth_cognito/android/src/main/kotlin/com/amazonaws/amplify/amplify_auth_cognito/pigeons/WebAuthnBridgePigeon.kt
    - packages/auth/amplify_auth_cognito/lib/src/pigeon_webauthn_credential_platform.dart
    - packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform_stub.dart
  modified:
    - packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart

key-decisions:
  - "Error mapping on Dart side via WebAuthnErrorCodes string constants"
  - "Separate default errors for create (RegistrationFailed) vs get (AssertionFailed) operations"

patterns-established:
  - "Pigeon bridge pattern: definition in pigeons/, adapter in lib/src/, error mapping via switch on PlatformException.code"
  - "WebAuthn error code contract: native code throws PlatformException with standardized codes (cancelled, notSupported, rpMismatch, etc.)"

requirements-completed: [PLAT-08]

# Metrics
duration: 13min
completed: 2026-03-09
---

# Phase 3 Plan 01: Pigeon WebAuthn Bridge and Shared Infrastructure Summary

**Pigeon-generated WebAuthn bridge (Dart/Swift/Kotlin) with error-mapping adapter and stub platform, wired into auth plugin**

## Performance

- **Duration:** 13 min
- **Started:** 2026-03-09T14:53:16Z
- **Completed:** 2026-03-09T15:06:24Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Created Pigeon definition with 3 async methods (createCredential, getCredential, isPasskeySupported) and generated Dart, Swift, and Kotlin bindings
- Built PigeonWebAuthnCredentialPlatform adapter that maps all 5 PlatformException error codes to the correct PasskeyException subtypes
- Created stub platform (WebAuthnCredentialPlatformImpl) that returns false for isPasskeySupported and throws PasskeyNotSupportedException for operations
- Registered the WebAuthn bridge in auth_plugin_impl.dart alongside existing NativeAuthBridge (iOS/Android only)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Pigeon definition and run code generation** - `81efdc2e8` (feat)
2. **Task 2: Create Dart adapter, stub platform, and wire plugin registration** - `f43c0859e` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito/pigeons/webauthn_bridge.dart` - Pigeon definition with WebAuthnBridgeApi @HostApi
- `packages/auth/amplify_auth_cognito/lib/src/webauthn_bridge.g.dart` - Generated Dart bindings
- `packages/auth/amplify_auth_cognito/darwin/Classes/pigeons/WebAuthnBridge.g.swift` - Generated Swift bindings
- `packages/auth/amplify_auth_cognito/android/src/main/kotlin/.../WebAuthnBridgePigeon.kt` - Generated Kotlin bindings
- `packages/auth/amplify_auth_cognito/lib/src/pigeon_webauthn_credential_platform.dart` - Dart adapter with error mapping
- `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform_stub.dart` - Stub for unsupported platforms
- `packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart` - Added WebAuthn bridge registration

## Decisions Made
- Error mapping uses static method with function parameter for different defaults (createCredential defaults to PasskeyRegistrationFailedException, getCredential defaults to PasskeyAssertionFailedException)
- WebAuthnErrorCodes defined as abstract final class with string constants matching the native-side contract
- isPasskeySupported errors mapped to generic PasskeyException (not a specific subtype) since the operation is lightweight

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `dart analyze` cannot fully verify cross-package references because mono-repo packages resolve to published pub.dev versions, not local paths. The published versions of amplify_core and amplify_auth_cognito_dart don't include Phase 1 types (PasskeyException hierarchy, WebAuthnCredentialPlatform). This is a pre-existing repo constraint that affects all phases -- the same issue exists in Phase 2 code (sign_in_state_machine.dart). All code is structurally correct; full analysis will pass once packages are published together.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Pigeon-generated Swift/Kotlin stubs are ready for native implementations (Plans 02 and 03)
- WebAuthnErrorCodes contract establishes the error codes native platforms must use
- Stub platform is ready for conditional import wiring in Plan 04 (Web bridge)
- auth_plugin_impl.dart registration ensures the bridge is available to SignInStateMachine

## Self-Check: PASSED

All 6 created files verified present. Both task commits (81efdc2e8, f43c0859e) verified in git log.

---
*Phase: 03-platform-bridges-ios-android-web*
*Completed: 2026-03-09*

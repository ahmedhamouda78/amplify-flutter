---
phase: 03-platform-bridges-ios-android-web
plan: 03
subsystem: auth
tags: [android, webauthn, passkey, credential-manager, kotlin, pigeon]

# Dependency graph
requires:
  - phase: 03-platform-bridges-ios-android-web
    plan: 01
    provides: "Pigeon-generated WebAuthnBridgeApi Kotlin interface and FlutterError class"
  - phase: 01-core-types-and-models
    provides: "PasskeyException hierarchy and WebAuthnCredentialPlatform interface"
provides:
  - "Android WebAuthnBridgeImpl with CredentialManager for passkey create/get/isSupported"
  - "Plugin registration wiring in AmplifyAuthCognitoPlugin.onAttachedToEngine"
affects: []

# Tech tracking
tech-stack:
  added: [androidx.credentials:1.3.0, androidx.credentials-play-services-auth:1.3.0]
  patterns: [credential-manager-coroutine-bridge, activity-provider-lambda]

key-files:
  created:
    - packages/auth/amplify_auth_cognito/android/src/main/kotlin/com/amazonaws/amplify/amplify_auth_cognito/WebAuthnBridgeImpl.kt
  modified:
    - packages/auth/amplify_auth_cognito/android/build.gradle
    - packages/auth/amplify_auth_cognito/android/src/main/kotlin/com/amazonaws/amplify/amplify_auth_cognito/AmplifyAuthCognitoPlugin.kt

key-decisions:
  - "FlutterError from Pigeon-generated code used directly (same package, no import needed)"
  - "isPasskeySupported uses Build.VERSION.SDK_INT >= 28 since Play Services fallback handles API 28-33"
  - "Activity provider uses lambda to always get current mainActivity reference from plugin lifecycle"

patterns-established:
  - "CredentialManager bridge: raw JSON in/out (no manual parsing), coroutine scope with SupervisorJob, dispose on detach"
  - "Error mapping: CreateCredentialCancellationException -> cancelled, CreateCredentialProviderConfigurationException -> notSupported, others -> registrationFailed/assertionFailed"

requirements-completed: [PLAT-02, PLAT-08]

# Metrics
duration: 2min
completed: 2026-03-09
---

# Phase 3 Plan 03: Android WebAuthn Bridge Summary

**Android CredentialManager bridge implementing passkey creation/assertion via coroutines with full exception-to-FlutterError mapping**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-09T15:10:52Z
- **Completed:** 2026-03-09T15:13:09Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created WebAuthnBridgeImpl implementing all 3 Pigeon-generated WebAuthnBridgeApi methods using CredentialManager
- Mapped all CredentialManager exception types to correct FlutterError codes matching Dart-side WebAuthnErrorCodes contract
- Registered bridge in AmplifyAuthCognitoPlugin with activity provider lambda and proper lifecycle cleanup

## Task Commits

Each task was committed atomically:

1. **Task 1: Add credentials dependency and create WebAuthnBridgeImpl.kt** - `b1446f2c7` (feat)
2. **Task 2: Register WebAuthn bridge in AmplifyAuthCognitoPlugin.kt** - `4f31215b0` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito/android/build.gradle` - Added androidx.credentials and credentials-play-services-auth dependencies
- `packages/auth/amplify_auth_cognito/android/src/main/kotlin/.../WebAuthnBridgeImpl.kt` - Android WebAuthn bridge with CredentialManager, coroutine scope, error mapping
- `packages/auth/amplify_auth_cognito/android/src/main/kotlin/.../AmplifyAuthCognitoPlugin.kt` - Bridge creation in onAttachedToEngine, dispose in onDetachedFromEngine

## Decisions Made
- Used Pigeon-generated FlutterError class directly since it is in the same package (com.amazonaws.amplify.amplify_auth_cognito)
- isPasskeySupported checks Build.VERSION.SDK_INT >= 28 (API P) as basic check since credentials-play-services-auth handles the fallback for devices without native CredentialManager
- Activity provider uses lambda `{ mainActivity }` to always capture the current activity from plugin lifecycle methods

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Android bridge ready for end-to-end testing with passkey ceremonies
- Plan 04 (Web bridge) can proceed independently
- All three platform bridges (iOS from Plan 02, Android from Plan 03, Web from Plan 04) will complete the native layer

## Self-Check: PASSED

All 3 modified/created files verified present. Both task commits (b1446f2c7, 4f31215b0) verified in git log. All must-have artifacts confirmed.

---
*Phase: 03-platform-bridges-ios-android-web*
*Completed: 2026-03-09*

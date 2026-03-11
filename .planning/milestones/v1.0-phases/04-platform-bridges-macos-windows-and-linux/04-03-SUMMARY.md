---
phase: 04-platform-bridges-macos-windows-and-linux
plan: 03
subsystem: auth
tags: [webauthn, passkey, ffi, pigeon, macos, windows, linux, platform-bridge]

# Dependency graph
requires:
  - phase: 04-platform-bridges-macos-windows-and-linux
    provides: "WindowsWebAuthnPlatform FFI bridge (plan 01), LinuxWebAuthnPlatform FFI bridge (plan 02)"
  - phase: 03-ios-android-web-platform-bridges
    provides: "Pigeon WebAuthn bridge, PigeonWebAuthnCredentialPlatform adapter, auth_plugin_impl.dart registration"
provides:
  - "All-platform WebAuthn registration in auth_plugin_impl.dart (iOS/Android/macOS via Pigeon, Windows/Linux via FFI)"
  - "macOS podspec updated to 13.5 with AuthenticationServices framework"
  - "Complete platform bridge wiring for 6-platform passkey support"
affects: [05-testing-and-integration, 06-documentation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FFI platform bridges early-return before Pigeon path in addPlugin()"
    - "macOS shares Darwin Pigeon path with iOS/Android (no separate implementation)"

key-files:
  created: []
  modified:
    - "packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart"
    - "packages/auth/amplify_auth_cognito/darwin/amplify_auth_cognito.podspec"

key-decisions:
  - "macOS shares Pigeon bridge registration with iOS/Android (single Darwin path)"
  - "Windows/Linux FFI bridges early-return before Pigeon setup to avoid loading native plugins"
  - "macOS podspec raised to 13.5 (Ventura) for ASAuthorizationController compile-time availability"

patterns-established:
  - "FFI platforms register and return early; Pigeon platforms fall through to shared Darwin/mobile code"

requirements-completed: [PLAT-03, PLAT-08]

# Metrics
duration: 3min
completed: 2026-03-10
---

# Phase 4 Plan 03: Platform Bridge Wiring Summary

**All-platform WebAuthn bridge registration in auth_plugin_impl.dart with macOS Pigeon path, Windows/Linux FFI early-return, and podspec deployment target 13.5**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-10T12:41:18Z
- **Completed:** 2026-03-10T12:44:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Wired macOS into the existing Pigeon bridge path alongside iOS and Android
- Added Windows and Linux FFI-based WebAuthn platform registration with early-return pattern
- Raised macOS podspec deployment target to 13.5 and added AuthenticationServices framework
- Updated signUp validation data guard to include macOS

## Task Commits

Each task was committed atomically:

1. **Task 1: Update auth_plugin_impl.dart with all-platform WebAuthn registration** - `8d773e652` (feat)
2. **Task 2: Fix macOS podspec and add ffi dependency to pubspec** - `8aaef437f` (chore)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart` - All-platform WebAuthn bridge registration (macOS/Windows/Linux)
- `packages/auth/amplify_auth_cognito/darwin/amplify_auth_cognito.podspec` - macOS deployment target 13.5, AuthenticationServices framework

## Decisions Made
- macOS shares the Pigeon bridge registration path with iOS/Android since Darwin implementation is shared via sharedDarwinSource
- Windows and Linux register FFI bridges and early-return to avoid attempting to load native Pigeon plugins
- Raised macOS deployment target to 13.5 (not just runtime guard) for ASAuthorizationController compile-time API availability
- ffi dependency was already present in pubspec.yaml from Plan 02 -- no change needed

## Deviations from Plan

None - plan executed exactly as written. Note: ffi dependency was already in pubspec.yaml from a prior plan, so no pubspec change was needed.

## Issues Encountered

Pre-existing `dart analyze` error on `WebAuthnCredentialPlatform` type resolution exists when analyzing the single file in isolation (present before this plan's changes). The type IS correctly exported from `amplify_auth_cognito_dart` barrel file. This is an out-of-scope pre-existing issue.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All six platform bridges are now wired into the auth plugin registration
- Platform-specific WebAuthn support available at runtime via isPasskeySupported()
- Ready for integration testing phase

---
*Phase: 04-platform-bridges-macos-windows-and-linux*
*Completed: 2026-03-10*

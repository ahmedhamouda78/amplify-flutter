---
phase: 04-platform-bridges-macos-windows-and-linux
plan: 01
subsystem: auth
tags: [ffi, windows, webauthn, windows-hello, dart-ffi, passkeys]

# Dependency graph
requires:
  - phase: 03-platform-bridges-ios-android-and-web
    provides: WebAuthnCredentialPlatform interface and PasskeyException hierarchy
provides:
  - Windows FFI bindings to webauthn.dll (WebAuthnBindings class)
  - WindowsWebAuthnPlatform implementing WebAuthnCredentialPlatform
  - JSON pass-through mode for Windows WebAuthn API v4+
affects: [04-platform-bridges-macos-windows-and-linux, 05-integration-and-registration]

# Tech tracking
tech-stack:
  added: [dart:ffi, package:ffi (Arena/calloc/Utf16)]
  patterns: [raw-pointer-offset-structs, json-pass-through-ffi, arena-memory-management]

key-files:
  created:
    - packages/auth/amplify_auth_cognito/lib/src/windows/webauthn_bindings.dart
    - packages/auth/amplify_auth_cognito/lib/src/windows/windows_webauthn_platform.dart
  modified:
    - packages/auth/amplify_auth_cognito/pubspec.yaml

key-decisions:
  - "Used raw pointer offsets instead of full Struct subclasses for large version-dependent Windows structs"
  - "JSON pass-through mode (API v4+) avoids manually constructing full C struct hierarchy"
  - "Added ffi ^2.0.2 dependency to amplify_auth_cognito for Arena/calloc/Utf16 extensions"

patterns-established:
  - "Raw offset-based struct access: allocate Uint8 buffer and write fields at known byte offsets"
  - "Windows FFI error mapping: HRESULT codes to PasskeyException subtypes with hex debug info"
  - "DLL injection via constructor parameter for testability of FFI bindings"

requirements-completed: [PLAT-05, PLAT-08]

# Metrics
duration: 5min
completed: 2026-03-10
---

# Phase 04 Plan 01: Windows WebAuthn FFI Bridge Summary

**Windows WebAuthn FFI bridge using JSON pass-through to webauthn.dll with HRESULT-to-PasskeyException error mapping**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T12:13:08Z
- **Completed:** 2026-03-10T12:18:08Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created WebAuthnBindings class with lazy FFI lookups for all 7 Windows API functions
- Implemented WindowsWebAuthnPlatform with createCredential, getCredential, and isPasskeySupported
- Used JSON pass-through mode (API v4+) to avoid manually defining 20+ field C struct hierarchy
- Mapped HRESULT error codes (NTE_USER_CANCELLED, NTE_NOT_FOUND, NTE_INVALID_PARAMETER) to PasskeyException subtypes

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Windows WebAuthn FFI bindings** - `f1ead5eb5` (feat)
2. **Task 2: Create WindowsWebAuthnPlatform implementation** - `828e8e2f5` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito/lib/src/windows/webauthn_bindings.dart` - FFI typedefs, struct offset helpers, constants, and WebAuthnBindings class for webauthn.dll/user32.dll
- `packages/auth/amplify_auth_cognito/lib/src/windows/windows_webauthn_platform.dart` - WindowsWebAuthnPlatform implementing WebAuthnCredentialPlatform via FFI with JSON pass-through
- `packages/auth/amplify_auth_cognito/pubspec.yaml` - Added ffi ^2.0.2 dependency

## Decisions Made
- Used raw pointer offsets (allocate `Uint8` buffer, write at known byte offsets) instead of full `Struct` subclasses for the large version-dependent MakeCredential/GetAssertion options structs -- avoids complexity of correctly aligning 20+ fields including nested pointers across API versions
- JSON pass-through mode (API v4+) sends the full options JSON directly to the native API and reads JSON response directly from result struct -- matches the project's JSON string boundary pattern
- Added `ffi: ^2.0.2` to `amplify_auth_cognito` pubspec (same version as `amplify_auth_cognito_dart` and `amplify_secure_storage_dart`)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added ffi dependency to pubspec.yaml**
- **Found during:** Task 1 (FFI bindings creation)
- **Issue:** `package:ffi` not listed in `amplify_auth_cognito/pubspec.yaml` dependencies, required for Arena/calloc/Utf16
- **Fix:** Added `ffi: ^2.0.2` to dependencies (same version as sibling packages)
- **Files modified:** `packages/auth/amplify_auth_cognito/pubspec.yaml`
- **Verification:** `dart analyze` resolves `package:ffi/ffi.dart` import
- **Committed in:** f1ead5eb5 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed deprecated elementAt usage**
- **Found during:** Task 2 (platform implementation)
- **Issue:** `Pointer.elementAt()` is deprecated in Dart 3.9+; analyzer flagged deprecation warnings
- **Fix:** Replaced all `elementAt(offset)` calls with `+ offset` operator
- **Files modified:** `windows_webauthn_platform.dart`
- **Verification:** No deprecation warnings in analyzer output
- **Committed in:** 828e8e2f5 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both essential for correct compilation. No scope creep.

## Issues Encountered
- Cross-package analyzer errors (uri_does_not_exist, implements_non_class) are expected mono-repo behavior -- same errors appear on the existing `pigeon_webauthn_credential_platform.dart` file. These resolve when analyzed as part of the full package graph.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Windows FFI bridge complete, ready for registration in `auth_plugin_impl.dart` (Phase 5 integration)
- Linux FFI bridge (Plan 03) and macOS enablement (Plan 02) are independent and can proceed in parallel

---
*Phase: 04-platform-bridges-macos-windows-and-linux*
*Completed: 2026-03-10*

## Self-Check: PASSED
- [x] webauthn_bindings.dart exists
- [x] windows_webauthn_platform.dart exists
- [x] Commit f1ead5eb5 found
- [x] Commit 828e8e2f5 found

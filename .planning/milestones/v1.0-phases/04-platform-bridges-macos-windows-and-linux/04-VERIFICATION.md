---
phase: 04-platform-bridges-macos-windows-and-linux
verified: 2026-03-10T13:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 4: Platform Bridges -- macOS, Windows, and Linux Verification Report

**Phase Goal:** Extend passkey support to the remaining three platforms: macOS (shared Darwin), Windows (Windows Hello), and Linux (best-effort).
**Verified:** 2026-03-10T13:00:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | macOS bridge shares iOS Darwin implementation via ASAuthorizationController (macOS 13.5+) | VERIFIED | `auth_plugin_impl.dart` line 79 includes `Platform.isMacOS` in Pigeon guard; podspec `s.osx.deployment_target = '13.5'`; `AuthenticationServices` framework added; `pubspec.yaml` has `sharedDarwinSource: true` for macOS |
| 2 | Windows bridge wraps Windows Hello FIDO2 API via FFI bindings | VERIFIED | `webauthn_bindings.dart` (403 lines) defines `WebAuthnBindings` class with all 7 function lookups; `windows_webauthn_platform.dart` (398 lines) implements `WebAuthnCredentialPlatform` with JSON pass-through, Arena memory management, HRESULT error mapping |
| 3 | Linux bridge provides best-effort support via libfido2 FFI or returns isPasskeySupported() = false | VERIFIED | `libfido2_bindings.dart` (518 lines) with `LibFido2Bindings` class; `linux_webauthn_platform.dart` (505 lines) catches `ArgumentError` on `DynamicLibrary.open`, sets `_bindings = null`, `isPasskeySupported()` returns `_bindings != null` |
| 4 | isPasskeySupported() correctly reports availability on all six platforms | VERIFIED | Windows: checks API version >= 4 + `IsUserVerifyingPlatformAuthenticatorAvailable`; Linux: checks `_bindings != null`; macOS/iOS/Android: Pigeon bridge to native `ASAuthorizationController`/`CredentialManager`; Web: handled by existing conditional import |
| 5 | Graceful error handling when passkeys are unavailable on a platform | VERIFIED | Windows: `isPasskeySupported` catches all exceptions, returns false; throws `PasskeyNotSupportedException` for API < 4. Linux: catches `ArgumentError` on DLL load; `_ensureSupported()` throws `PasskeyNotSupportedException`. Error mapping: cancelled, not-found, timeout, PIN, UV blocked all mapped to typed `PasskeyException` subtypes |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `packages/auth/amplify_auth_cognito/lib/src/windows/webauthn_bindings.dart` | FFI typedefs, struct definitions, and function lookups for webauthn.dll | VERIFIED | 403 lines; `WebAuthnBindings` class with lazy final lookups for all 7 API functions; struct offset helpers for JSON pass-through |
| `packages/auth/amplify_auth_cognito/lib/src/windows/windows_webauthn_platform.dart` | WebAuthnCredentialPlatform implementation for Windows | VERIFIED | 398 lines; implements `WebAuthnCredentialPlatform`; `createCredential`, `getCredential`, `isPasskeySupported` all substantive |
| `packages/auth/amplify_auth_cognito/lib/src/linux/libfido2_bindings.dart` | FFI function lookups for libfido2.so with dynamic loading | VERIFIED | 518 lines; `LibFido2Bindings` class with late final lookups for device discovery, credential creation, assertion APIs |
| `packages/auth/amplify_auth_cognito/lib/src/linux/linux_webauthn_platform.dart` | WebAuthnCredentialPlatform implementation for Linux | VERIFIED | 505 lines; implements `WebAuthnCredentialPlatform`; device discovery, ceremony execution, manual JSON assembly, error mapping |
| `packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart` | Platform registration for macOS (Pigeon), Windows (FFI), Linux (FFI) | VERIFIED | Lines 65-76: Windows/Linux FFI early-return; Line 79: `Platform.isMacOS` in Pigeon guard; Line 128: macOS added to signUp validation data guard |
| `packages/auth/amplify_auth_cognito/darwin/amplify_auth_cognito.podspec` | Updated macOS deployment target | VERIFIED | Line 30: `s.osx.deployment_target = '13.5'`; Line 22: `AuthenticationServices` in osx.frameworks |
| `packages/auth/amplify_auth_cognito/pubspec.yaml` | ffi dependency for Windows/Linux | VERIFIED | Line 30: `ffi: ^2.0.2`; Line 29: `crypto: ^3.0.7` (for Linux SHA-256) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `windows_webauthn_platform.dart` | `webauthn_bindings.dart` | import | WIRED | Line 13: `import 'package:amplify_auth_cognito/src/windows/webauthn_bindings.dart'` |
| `windows_webauthn_platform.dart` | `WebAuthnCredentialPlatform` | implements | WIRED | Line 24: `class WindowsWebAuthnPlatform implements WebAuthnCredentialPlatform` |
| `linux_webauthn_platform.dart` | `libfido2_bindings.dart` | import | WIRED | Line 14: `import 'package:amplify_auth_cognito/src/linux/libfido2_bindings.dart'` |
| `linux_webauthn_platform.dart` | `WebAuthnCredentialPlatform` | implements | WIRED | Line 26: `class LinuxWebAuthnPlatform implements WebAuthnCredentialPlatform` |
| `auth_plugin_impl.dart` | `windows_webauthn_platform.dart` | import + register | WIRED | Line 16: import; Lines 65-70: `Platform.isWindows` guard registers `WindowsWebAuthnPlatform()` |
| `auth_plugin_impl.dart` | `linux_webauthn_platform.dart` | import + register | WIRED | Line 12: import; Lines 71-76: `Platform.isLinux` guard registers `LinuxWebAuthnPlatform()` |
| `auth_plugin_impl.dart` | `WebAuthnCredentialPlatform` DI | `addInstance` | WIRED | Line 66, 72, 95: `stateMachine.addInstance<WebAuthnCredentialPlatform>(...)` for Windows, Linux, and Pigeon paths |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| PLAT-03 | 04-03 | macOS platform bridge shares iOS/Darwin ASAuthorizationController (macOS 13.5+) | SATISFIED | Pigeon bridge guard includes `Platform.isMacOS`; podspec target 13.5; `sharedDarwinSource: true` |
| PLAT-05 | 04-01 | Windows platform bridge wraps Windows Hello / FIDO2 APIs via FFI | SATISFIED | `WebAuthnBindings` + `WindowsWebAuthnPlatform` with JSON pass-through to webauthn.dll |
| PLAT-06 | 04-02 | Linux platform bridge provides best-effort via libfido2 FFI or returns isPasskeySupported() = false | SATISFIED | `LibFido2Bindings` + `LinuxWebAuthnPlatform` with graceful fallback on missing libfido2 |
| PLAT-08 | 04-01, 04-02, 04-03 | Platform bridges map platform-specific errors to typed PasskeyException subtypes | SATISFIED | Windows: HRESULT mapping (cancelled, not-found, invalid-param, default); Linux: libfido2 error mapping (not-allowed, timeout, PIN, UV-blocked, default) |

No orphaned requirements found. All 4 requirement IDs (PLAT-03, PLAT-05, PLAT-06, PLAT-08) declared in ROADMAP Phase 4 are covered by plans and verified.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | - | - | No anti-patterns detected in any phase artifacts |

### Human Verification Required

### 1. Windows WebAuthn ceremony end-to-end

**Test:** Run the app on Windows, trigger passkey sign-in, verify Windows Hello dialog appears and completes.
**Expected:** WebAuthn ceremony dialog appears, user can authenticate via Windows Hello, JSON response returned.
**Why human:** Cannot programmatically invoke Windows Hello API in CI; requires real hardware and user interaction.

### 2. Linux libfido2 with USB security key

**Test:** On Linux with libfido2 installed and a USB FIDO2 key inserted, trigger passkey sign-in.
**Expected:** Device discovered via `fido_dev_info_manifest`, ceremony completes, JSON response assembled and returned.
**Why human:** Requires physical USB FIDO2 security key and Linux environment with libfido2 installed.

### 3. macOS ASAuthorizationController passkey dialog

**Test:** On macOS 13.5+, trigger passkey sign-in, verify system passkey dialog appears.
**Expected:** ASAuthorizationController presents the macOS passkey dialog, same as iOS behavior.
**Why human:** Requires macOS 13.5+ machine with passkey-capable account; native UI interaction cannot be automated.

### 4. Graceful degradation on unsupported platforms

**Test:** On Linux without libfido2, verify `isPasskeySupported()` returns false and operations throw `PasskeyNotSupportedException`.
**Expected:** No crash, clean error messages, app continues functioning for non-passkey auth flows.
**Why human:** Requires testing on a clean Linux environment without libfido2 installed.

### Gaps Summary

No gaps found. All five success criteria are verified through code inspection:

1. macOS shares the existing Pigeon bridge path with iOS/Android via `Platform.isMacOS` guard and `sharedDarwinSource: true` in pubspec. Podspec deployment target raised to 13.5 with AuthenticationServices framework.

2. Windows FFI bridge has comprehensive bindings (7 function lookups, struct offset helpers) and a complete `WindowsWebAuthnPlatform` implementation using JSON pass-through mode for API v4+.

3. Linux FFI bridge has comprehensive libfido2 bindings and a complete `LinuxWebAuthnPlatform` with graceful fallback when the library is unavailable.

4. All six platforms register `WebAuthnCredentialPlatform` via the auth plugin: iOS/Android/macOS through Pigeon, Windows/Linux through FFI, Web through existing conditional import.

5. Error handling is thorough: Windows maps HRESULT codes, Linux maps libfido2 error codes, both gracefully handle unavailability via `isPasskeySupported()`.

All commits verified in git history: f1ead5eb5, 828e8e2f5, 0f4020609, 0be7966ae, 8d773e652, 8aaef437f.

---

_Verified: 2026-03-10T13:00:00Z_
_Verifier: Claude (gsd-verifier)_

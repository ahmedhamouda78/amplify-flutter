---
phase: 4
slug: platform-bridges-macos-windows-and-linux
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-09
updated: 2026-03-11
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `package:test` (Dart) / `flutter_test` (Flutter) |
| **Config file** | None — uses standard `dart test` runner |
| **Quick run command** | `dart test packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` |
| **Full suite command** | `dart test packages/auth/amplify_auth_cognito_test/test/` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dart test packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart`
- **After every plan wave:** Run `dart test packages/auth/amplify_auth_cognito_test/test/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | PLAT-03 | manual-only | See Manual-Only Verifications section | N/A (platform guard) | ✅ manual |
| 04-02-01 | 02 | 2 | PLAT-05 | unit (FFI bridge, error mapping) | `flutter test packages/auth/amplify_auth_cognito/test/windows_webauthn_platform_test.dart --no-pub` | Yes | ✅ green |
| 04-02-02 | 02 | 2 | PLAT-08 | unit (HRESULT mapping) | `flutter test packages/auth/amplify_auth_cognito/test/windows_webauthn_platform_test.dart --no-pub` | Yes (covered in 04-02-01) | ✅ green |
| 04-03-01 | 03 | 2 | PLAT-06 | unit (FFI bridge, fallback, error mapping) | `flutter test packages/auth/amplify_auth_cognito/test/linux_webauthn_platform_test.dart --no-pub` | Yes | ✅ green |
| 04-03-02 | 03 | 2 | PLAT-08 | unit (libfido2 error mapping) | `flutter test packages/auth/amplify_auth_cognito/test/linux_webauthn_platform_test.dart --no-pub` | Yes (covered in 04-03-01) | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ✅ manual (manual-only verification)*

---

## Wave 0 Requirements

- [x] `packages/auth/amplify_auth_cognito/test/windows_webauthn_platform_test.dart` — PLAT-05 + PLAT-08: Windows FFI bridge tests (17 tests covering isPasskeySupported, createCredential, getCredential, HRESULT error mapping: NTE_USER_CANCELLED → PasskeyCancelledException, NTE_NOT_FOUND → PasskeyAssertionFailedException, NTE_INVALID_PARAMETER → PasskeyRegistrationFailedException/AssertionFailedException, API version gating, no active window handling)
- [x] `packages/auth/amplify_auth_cognito/test/linux_webauthn_platform_test.dart` — PLAT-06 + PLAT-08: Linux FFI bridge tests (15 tests covering isPasskeySupported with null bindings, _ensureSupported throws PasskeyNotSupportedException, createCredential/getCredential success, libfido2 error mapping: fidoErrNotAllowed → PasskeyCancelledException, fidoErrActionTimeout → PasskeyCancelledException, fidoErrPinRequired → PasskeyAssertionFailedException, fidoErrUvBlocked → PasskeyAssertionFailedException, device discovery failures)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| macOS Platform.isMacOS guard in auth_plugin_impl.dart | PLAT-03 | Platform guard cannot be easily unit tested; macOS shares Darwin Pigeon bridge which IS tested in pigeon_webauthn_credential_platform_test.dart | Verify line 79 of auth_plugin_impl.dart includes `Platform.isMacOS` in Pigeon guard |
| Full MakeCredential ceremony on Windows | PLAT-05 | Requires Windows Hello biometric prompt | Run example app on Windows, create passkey, verify credential returned |
| Full GetAssertion ceremony on Windows | PLAT-05 | Requires Windows Hello biometric prompt | Run example app on Windows, sign in with passkey, verify assertion returned |
| Full MakeCredential ceremony on Linux | PLAT-06 | Requires physical FIDO2 USB key | Run example app on Linux with FIDO2 key, create passkey |
| Full GetAssertion ceremony on Linux | PLAT-06 | Requires physical FIDO2 USB key | Run example app on Linux with FIDO2 key, sign in with passkey |
| Full passkey create/sign-in on macOS | PLAT-03 | Requires Touch ID or password on macOS 13.5+ | Run example app on macOS 13.5+, create and verify passkey |
| Graceful failure on Linux without libfido2 | PLAT-06 | Requires Linux without libfido2 installed | Run example app on clean Linux, verify isPasskeySupported() returns false |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (04-01-01 is manual-only due to platform guard; all others have automated tests)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (04-02-01, 04-02-02, 04-03-01, 04-03-02 all have automated tests)
- [x] Wave 0 covers all MISSING references (windows_webauthn_platform_test.dart and linux_webauthn_platform_test.dart created and passing)
- [x] No watch-mode flags (all commands use `flutter test --no-pub`)
- [x] Feedback latency < 30s (17 Windows tests + 15 Linux tests run in ~2 seconds total)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** PASSED

**Nyquist Auditor Notes (2026-03-11):**
- Created comprehensive Windows FFI bridge tests (17 tests) covering all PLAT-05 + PLAT-08 requirements
- Created comprehensive Linux FFI bridge tests (15 tests) covering all PLAT-06 + PLAT-08 requirements
- PLAT-03 (macOS platform guard) moved to manual-only section as it's a simple Platform.isMacOS guard that shares the Darwin Pigeon bridge
- All tests use mock bindings to avoid real FFI dependencies in CI
- Error mapping thoroughly tested: Windows HRESULT codes and Linux libfido2 error codes mapped to correct PasskeyException subtypes
- Test commands use `flutter test --no-pub` to run in the existing environment

---

## Validation Audit 2026-03-11

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 2 (automated tests) |
| Escalated | 1 (manual-only: PLAT-03 macOS platform guard) |

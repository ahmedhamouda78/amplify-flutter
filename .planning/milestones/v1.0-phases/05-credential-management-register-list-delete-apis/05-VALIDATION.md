---
phase: 5
slug: credential-management-register-list-delete-apis
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-10
updated: 2026-03-11
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dart test package 1.22.1 |
| **Config file** | none — Wave 0 creates test files |
| **Quick run command** | `dart test <specific_test_file>` |
| **Full suite command** | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dart test <specific_test_file> -x`
- **After every plan wave:** Run `dart test packages/auth/amplify_auth_cognito_test/test/plugin/{associate,list,delete,is_passkey}*`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 0 | AUTH-02 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart` | ✅ | ✅ green |
| 05-01-02 | 01 | 0 | AUTH-03 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/list_webauthn_credentials_test.dart` | ✅ | ✅ green |
| 05-01-03 | 01 | 0 | AUTH-04 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/delete_webauthn_credential_test.dart` | ✅ | ✅ green |
| 05-01-04 | 01 | 0 | AUTH-05 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/is_passkey_supported_test.dart` | ✅ | ✅ green |
| 05-02-01 | 02 | 1 | AUTH-02 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart` | ✅ | ✅ green |
| 05-02-02 | 02 | 1 | AUTH-03 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/list_webauthn_credentials_test.dart` | ✅ | ✅ green |
| 05-02-03 | 02 | 1 | AUTH-04 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/delete_webauthn_credential_test.dart` | ✅ | ✅ green |
| 05-02-04 | 02 | 1 | AUTH-05 | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/is_passkey_supported_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart` — 4 tests for AUTH-02 (orchestration, cancellation, not supported, signed out) - all passing
- [x] `packages/auth/amplify_auth_cognito_test/test/plugin/list_webauthn_credentials_test.dart` — 4 tests for AUTH-03 (field mapping, pagination, empty list, signed out) - all passing
- [x] `packages/auth/amplify_auth_cognito_test/test/plugin/delete_webauthn_credential_test.dart` — 3 tests for AUTH-04 (successful delete, not found, signed out) - all passing
- [x] `packages/auth/amplify_auth_cognito_test/test/plugin/is_passkey_supported_test.dart` — 3 tests for AUTH-05 (platform available, unavailable, not supported) - all passing
- [x] `packages/auth/amplify_auth_cognito_test/common/mock_webauthn.dart` — mock WebAuthnCredentialPlatform

*Existing infrastructure covers framework — test package already in amplify_auth_cognito_test/pubspec.yaml.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s (tests run in ~1-2 seconds)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** PASSED - All 14 tests (8 previously skipped + 6 existing) now passing with HTTP client mocking

---

## Validation Audit 2026-03-11

| Metric | Count |
|--------|-------|
| Gaps found | 8 |
| Resolved | 8 (all automated via MockAWSHttpClient) |
| Escalated | 0 |

**Key technique:** Injected `MockAWSHttpClient` (from `package:aws_common`) into state machine via `addInstance<AWSHttpClient>()`, dispatching on `X-Amz-Target` header to return canned Cognito WebAuthn API responses.

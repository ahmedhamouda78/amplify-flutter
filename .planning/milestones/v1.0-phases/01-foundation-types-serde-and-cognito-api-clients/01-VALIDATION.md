---
phase: 01
slug: foundation-types-serde-and-cognito-api-clients
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-10
---

# Phase 01 -- Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dart test package (`package:test`) |
| **Config file** | pubspec.yaml (per package) |
| **Quick run command** | `dart test <file>` |
| **Full suite command** | `dart test packages/amplify_core/test/ && dart test packages/auth/amplify_auth_cognito_dart/test/` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dart test <changed_test_file>`
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | FLOW-04 | unit | `dart test packages/amplify_core/test/types/auth/auth_factor_type_webauthn_test.dart` | yes | green (3 tests) |
| 01-02-01 | 02 | 1 | FLOW-05 | unit | `dart test packages/auth/amplify_auth_cognito_dart/test/model/passkey_types_test.dart` | yes | green (5 tests) |
| 01-02-02 | 02 | 1 | FLOW-05 | unit | `dart test packages/auth/amplify_auth_cognito_dart/test/util/base64url_encode_test.dart` | yes | green (7 tests) |
| 01-03-01 | 03 | 1 | AUTH-06 | unit | `dart test packages/amplify_core/test/types/exception/passkey_exception_test.dart` | yes | green (16 tests) |
| 01-04-01 | 04 | 1 | PLAT-07 | unit | `dart test packages/auth/amplify_auth_cognito_dart/test/model/webauthn_credential_platform_test.dart` | yes | green (5 tests) |

*Status: green -- all 36 tests pass across 5 test files*

---

## Wave 0 Requirements

- [x] `packages/amplify_core/test/types/auth/auth_factor_type_webauthn_test.dart` -- FLOW-04 enum value tests
- [x] `packages/auth/amplify_auth_cognito_dart/test/model/passkey_types_test.dart` -- FLOW-05 serde round-trip tests
- [x] `packages/auth/amplify_auth_cognito_dart/test/util/base64url_encode_test.dart` -- FLOW-05 base64url tests
- [x] `packages/amplify_core/test/types/exception/passkey_exception_test.dart` -- AUTH-06 exception hierarchy tests
- [x] `packages/auth/amplify_auth_cognito_dart/test/model/webauthn_credential_platform_test.dart` -- PLAT-07 interface contract tests

*All test files created. Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Audit 2026-03-10

| Metric | Count |
|--------|-------|
| Gaps found | 4 |
| Resolved | 4 |
| Escalated | 0 |

All 4 gaps resolved with automated tests. 36 tests across 5 files, all passing green.

**Note:** `amplify_auth_cognito_dart` tests require `pubspec_overrides.yaml` with local path to `amplify_core` when running outside CI (the monorepo tooling handles this in CI).

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 1s (all tests complete in under 1 second)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-10

---
*Created: 2026-03-10*
*Auditor: Claude (gsd-validate-phase)*

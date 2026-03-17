---
phase: 1
slug: passkey-e2e-integration-tests-stub-platform-bridge-add-sign-in-and-registration-test-coverage
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | integration_test (Flutter SDK builtin) + flutter_test |
| **Config file** | none — configured via `testRunner.setupTests()` in each test file |
| **Quick run command** | `flutter test integration_test/webauthn_sign_in_test.dart --dart-define=AMPLIFY_ENVIRONMENT=webauthn` |
| **Full suite command** | `flutter test integration_test/ --dart-define=AMPLIFY_ENVIRONMENT=webauthn` |
| **Estimated runtime** | ~60 seconds (requires network for Cognito calls) |

---

## Sampling Rate

- **After every task commit:** Run quick run command on relevant test file
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| SIGN-IN-01 | 01 | 1 | Sign-in happy path | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-happy` | ❌ W0 | ⬜ pending |
| SIGN-IN-02 | 01 | 1 | User cancels passkey prompt | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-cancel` | ❌ W0 | ⬜ pending |
| SIGN-IN-03 | 01 | 1 | Passkey not supported | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-unsupported` | ❌ W0 | ⬜ pending |
| SIGN-IN-04 | 01 | 1 | Invalid credential response | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-invalid` | ❌ W0 | ⬜ pending |
| REG-01 | 01 | 1 | Registration happy path | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-happy` | ❌ W0 | ⬜ pending |
| REG-02 | 01 | 1 | Registration user cancels | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-cancel` | ❌ W0 | ⬜ pending |
| REG-03 | 01 | 1 | Registration platform unsupported | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-unsupported` | ❌ W0 | ⬜ pending |
| REG-04 | 01 | 1 | Registration already-registered | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-duplicate` | ❌ W0 | ⬜ pending |
| SELECT-01 | 01 | 1 | First-factor selection flow | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t first-factor-selection` | ❌ W0 | ⬜ pending |
| SUPPORT-01 | 01 | 1 | isPasskeySupported check | integration | `flutter test integration_test/webauthn_registration_test.dart -t is-supported` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `packages/test/amplify_auth_integration_test/lib/src/mock_webauthn_for_integration.dart` — extended MockWebAuthnCredentialPlatform for integration tests
- [ ] `packages/test/amplify_auth_integration_test/lib/src/webauthn_test_fixtures.dart` — test credential JSON constants
- [ ] `packages/test/amplify_auth_integration_test/lib/src/environments.dart` — add webauthn environment constant
- [ ] `packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart` — modify AmplifyAuthTestPlugin to accept WebAuthnCredentialPlatform

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

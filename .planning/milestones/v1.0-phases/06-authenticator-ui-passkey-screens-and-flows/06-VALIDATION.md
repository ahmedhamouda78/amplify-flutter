---
phase: 6
slug: authenticator-ui-passkey-screens-and-flows
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-10
validated: 2026-03-11
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + amplify_authenticator_test (workspace package) |
| **Config file** | none — test infrastructure in workspace package |
| **Quick run command** | `cd packages/authenticator/amplify_authenticator && flutter test {modified_test_file} --reporter compact --no-pub` |
| **Full suite command** | `cd packages/authenticator/amplify_authenticator && flutter test test --reporter compact --no-pub` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test {modified_test_file} --reporter compact`
- **After every plan wave:** Run `flutter test packages/authenticator/amplify_authenticator/test --reporter compact`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| UI-01 | 01 | 1 | UI-01 | unit | `cd packages/authenticator/amplify_authenticator && flutter test test/factor_selection_screen_test.dart --reporter compact --no-pub` | Yes | green |
| UI-02 | 01 | 1 | UI-02 | unit | `cd packages/authenticator/amplify_authenticator && flutter test test/passkey_signin_flow_test.dart --reporter compact --no-pub` | Yes | green |
| UI-03 | 02 | 1 | UI-03 | unit | `cd packages/authenticator/amplify_authenticator && flutter test test/passkey_registration_prompt_test.dart --reporter compact --no-pub` | Yes | green |
| UI-04 | 01 | 1 | UI-04 | unit | `cd packages/authenticator/amplify_authenticator && flutter test test/passkey_error_messages_test.dart --reporter compact --no-pub` | Yes | green |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [x] `test/factor_selection_screen_test.dart` — 10 tests for UI-01 (ContinueSignInWithFirstFactorSelection state, AuthenticatorStep enum)
- [x] `test/passkey_signin_flow_test.dart` — 8 tests for UI-02 (passkey sign-in flow states, AuthFactorType.webAuthn, PasswordlessSettings)
- [x] `test/passkey_registration_prompt_test.dart` — 16 tests for UI-03 (PasskeyPromptState, PasskeyRegistrationPrompts, PasswordlessSettings)
- [x] `test/passkey_error_messages_test.dart` — 24 tests for UI-04 (error states, ButtonResolverKeyType, MessageResolverKeyType, TitleResolver)
- [x] Mock implementations: MockWebAuthnCredentialPlatform already exists from Phase 5

*Existing amplify_authenticator_test package provides MockAuthenticatorApp, page objects.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Platform passkey ceremony triggers native dialog | UI-02 | Platform-specific native UI cannot be automated in flutter_test | Run example app, select passkey, verify native dialog appears |
| Passkey registration creates credential via platform | UI-03 | Requires actual platform WebAuthn bridge | Run example app, complete sign-in, verify registration prompt, tap create |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete (Nyquist validation 2026-03-11)

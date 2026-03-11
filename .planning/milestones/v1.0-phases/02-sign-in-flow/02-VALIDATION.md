---
phase: 02
slug: sign-in-flow
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-10
---

# Phase 02 -- Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dart test package (`package:test`) |
| **Config file** | pubspec.yaml (per package) |
| **Quick run command** | `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` |
| **Full suite command** | `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` |
| **Estimated runtime** | ~1 second |
| **Note** | Requires `pubspec_overrides.yaml` with local paths to `amplify_core`, `amplify_auth_cognito_dart`, etc. for local development (monorepo tooling handles this in CI). |

---

## Sampling Rate

- **After every task commit:** Run `dart test test/state/sign_in_webauthn_test.dart`
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | FLOW-02 | integration | `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` | yes | green (constants exercised in 4 tests) |
| 02-01-02 | 01 | 1 | FLOW-02 | integration | `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` | yes | green (sdk_bridge mapping exercised in all 6 tests) |
| 02-02-01 | 02 | 1 | FLOW-01, FLOW-03, AUTH-01 | integration | `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` | yes | green (6 tests) |
| 02-03-01 | 03 | 2 | FLOW-01, FLOW-02, FLOW-03, AUTH-01 | unit | `cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart` | yes | green (6 tests) |

*Status: green -- all 6 tests pass in 1 test file*

---

## Wave 0 Requirements

- [x] `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` -- FLOW-01 direct WEB_AUTHN challenge + auto-response
- [x] `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` -- FLOW-02 SELECT_CHALLENGE with webAuthn in available factors
- [x] `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` -- FLOW-03 two-step SELECT_CHALLENGE -> WEB_AUTHN flow
- [x] `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` -- AUTH-01 sign-in with passkey as first-factor

*All requirements covered by the 6 test cases in sign_in_webauthn_test.dart.*

---

## Test Case Detail

| # | Test Name | Requirement | Scenario |
|---|-----------|-------------|----------|
| 1 | `direct WEB_AUTHN challenge completes sign-in without user interaction` | FLOW-01, AUTH-01 | InitiateAuth -> WEB_AUTHN -> getCredential -> RespondToAuthChallenge -> tokens |
| 2 | `SELECT_CHALLENGE includes webAuthn in available factors` | FLOW-02 | InitiateAuth -> SELECT_CHALLENGE -> webAuthn in allowedFirstFactorTypes |
| 3 | `two-step SELECT_CHALLENGE -> WEB_AUTHN completes sign-in` | FLOW-03 | InitiateAuth -> SELECT_CHALLENGE -> answer WEB_AUTHN -> WEB_AUTHN challenge -> getCredential -> tokens |
| 4 | `emits failure when user cancels WebAuthn ceremony` | AUTH-01 | getCredential throws PasskeyCancelledException -> SignInFailure |
| 5 | `emits failure when WebAuthn platform is not registered` | AUTH-01 | No platform bridge -> PasskeyNotSupportedException -> SignInFailure |
| 6 | `emits failure when CREDENTIAL_REQUEST_OPTIONS is missing` | AUTH-01 | Missing challenge params -> PasskeyAssertionFailedException -> SignInFailure |

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Audit 2026-03-10

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Phase 2 VALIDATION.md reconstructed from execution artifacts (State B). All 6 tests confirmed passing green.

**Note:** Plan 01 (constants + SDK bridge) does not have standalone unit tests, but all constants and the SDK bridge mapping are exercised by the Plan 03 integration tests. `challengeParamCredentialRequestOptions` and `challengeParamCredential` appear in test mock setup; `ChallengeNameType.webAuthn.signInStep` is called implicitly during the state machine flow.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no consecutive tasks without automated verify
- [x] Wave 0 covers all phase requirements (FLOW-01, FLOW-02, FLOW-03, AUTH-01)
- [x] No watch-mode flags
- [x] Feedback latency < 1s (all tests complete in under 1 second)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-10

## Validation Audit 2026-03-11

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Re-audit confirmed: all 6 tests still pass green (`dart test test/state/sign_in_webauthn_test.dart` — 6/6 passing). All 4 requirements (AUTH-01, FLOW-01, FLOW-02, FLOW-03) have automated coverage. No new gaps.

---
*Created: 2026-03-10*
*Re-audited: 2026-03-11*
*Auditor: Claude (gsd-validate-phase)*
*State: (A) audit of existing VALIDATION.md*

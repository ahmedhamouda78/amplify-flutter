---
phase: 03
slug: platform-bridges-ios-android-web
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-09
audited: 2026-03-10
re_audited: 2026-03-11
---

# Phase 03 -- Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dart test package (`package:test`) for stub/interface tests; Flutter test for Pigeon adapter (requires Flutter SDK) |
| **Config file** | pubspec.yaml (per package) |
| **Quick run command** | `cd packages/auth/amplify_auth_cognito_dart && dart test test/model/webauthn_credential_platform_stub_test.dart` |
| **Full suite command** | `cd packages/auth/amplify_auth_cognito_dart && dart test test/model/webauthn_credential_platform_stub_test.dart test/model/webauthn_credential_platform_test.dart && cd ../amplify_auth_cognito && flutter test test/pigeon_webauthn_credential_platform_test.dart --no-pub` |
| **Estimated runtime** | ~5 seconds (Dart unit tests + Flutter adapter tests) |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 1 second

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | PLAT-08 | unit | `dart test test/model/webauthn_credential_platform_stub_test.dart` | yes | green (6 tests) -- requires pubspec_overrides.yaml |
| 03-01-02 | 01 | 1 | PLAT-08 | unit | `dart test test/model/webauthn_credential_platform_test.dart` | yes | green (5 tests) -- requires pubspec_overrides.yaml |
| 03-02-01 | 02 | 1 | PLAT-01 | manual | See Manual-Only Verifications | N/A | verified (code review) |
| 03-03-01 | 03 | 1 | PLAT-02 | manual | See Manual-Only Verifications | N/A | verified (code review) |
| 03-04-01 | 04 | 1 | PLAT-04 | manual | See Manual-Only Verifications | N/A | verified (code review) |
| 03-01-03 | 01 | 1 | PLAT-08 | unit (Flutter) | `cd packages/auth/amplify_auth_cognito && flutter test test/pigeon_webauthn_credential_platform_test.dart --no-pub` | yes | green (15 tests) -- requires pubspec_overrides.yaml + Flutter SDK |

*Status: green -- 26/26 automated tests pass across 3 files (11 Dart + 15 Flutter). Native bridges verified via code review + VERIFICATION.md.*

---

## Wave 0 Requirements

- [x] `packages/auth/amplify_auth_cognito_dart/test/model/webauthn_credential_platform_stub_test.dart` -- stub platform returns false and throws PasskeyNotSupportedException (6 tests)
- [x] `packages/auth/amplify_auth_cognito_dart/test/model/webauthn_credential_platform_test.dart` -- interface contract tests (5 tests)
- [x] `packages/auth/amplify_auth_cognito/test/pigeon_webauthn_credential_platform_test.dart` -- Pigeon adapter error mapping for all 5 error codes + success paths (15 tests)

*Requires `pubspec_overrides.yaml` with local `amplify_core` path override to compile, since published amplify_core 2.10.1 lacks Phase 1 passkey types. Flutter SDK required for Pigeon adapter tests.*

---

## Automated Test Details

### Stub Platform Tests (6 tests)
| # | Test Name | Validates |
|---|-----------|-----------|
| 1 | `isPasskeySupported returns false` | Unsupported platforms report correctly |
| 2 | `createCredential throws PasskeyNotSupportedException` | Registration blocked on unsupported platforms |
| 3 | `getCredential throws PasskeyNotSupportedException` | Assertion blocked on unsupported platforms |
| 4 | `createCredential exception message is descriptive` | Error messages are user-friendly |
| 5 | `getCredential exception message is descriptive` | Error messages are user-friendly |
| 6 | `stub can be constructed with const` | Const constructor for canonical instance |

### Interface Contract Tests (5 tests, from Phase 1)
| # | Test Name | Validates |
|---|-----------|-----------|
| 1 | `can be implemented by mock` | Interface is implementable |
| 2 | `createCredential has correct signature` | JSON string in/out contract |
| 3 | `getCredential has correct signature` | JSON string in/out contract |
| 4 | `isPasskeySupported has correct signature` | Bool return contract |
| 5 | `mock fulfills interface contract` | Full mock interaction |

### Pigeon Adapter Error Mapping Tests (15 tests, Flutter)
| # | Test Name | Validates |
|---|-----------|-----------|
| 1 | `createCredential returns result on success` | Happy path delegation |
| 2 | `createCredential maps cancelled to PasskeyCancelledException` | Cancelled error mapping |
| 3 | `createCredential maps notSupported to PasskeyNotSupportedException` | Not supported error mapping |
| 4 | `createCredential maps rpMismatch to PasskeyRpMismatchException` | RP mismatch error mapping |
| 5 | `createCredential maps unknown to PasskeyRegistrationFailedException` | Default create error |
| 6 | `createCredential preserves error message` | Message propagation |
| 7 | `createCredential preserves underlying exception` | Exception chain |
| 8 | `getCredential returns result on success` | Happy path delegation |
| 9 | `getCredential maps cancelled to PasskeyCancelledException` | Cancelled error mapping |
| 10 | `getCredential maps notSupported to PasskeyNotSupportedException` | Not supported error mapping |
| 11 | `getCredential maps rpMismatch to PasskeyRpMismatchException` | RP mismatch error mapping |
| 12 | `getCredential maps unknown to PasskeyAssertionFailedException` | Default get error |
| 13 | `isPasskeySupported returns true` | Supported platform |
| 14 | `isPasskeySupported returns false` | Unsupported platform |
| 15 | `isPasskeySupported maps error to PasskeyException` | Error handling |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Verification Status |
|----------|-------------|------------|---------------------|
| iOS passkey ceremonies (create/get) | PLAT-01 | Requires physical iOS 17.4+ device with biometrics; ASAuthorizationController cannot be unit tested | Verified: code review in VERIFICATION.md (WebAuthnBridgeImpl.swift, 388 lines) |
| Android passkey ceremonies (create/get) | PLAT-02 | Requires CredentialManager with Google Play Services on API 28+ device | Verified: code review in VERIFICATION.md (WebAuthnBridgeImpl.kt, 142 lines) |
| Web passkey ceremonies (create/get) | PLAT-04 | Requires browser with WebAuthn support + user gesture | Verified: code review in VERIFICATION.md (webauthn_credential_platform_html.dart, 238 lines) |
| Cross-platform Cognito round-trip | PLAT-08 | Requires real Cognito backend with passkey MFA | Deferred to integration testing |

**Justification for manual-only:** Native platform bridges interact with OS-level WebAuthn APIs (ASAuthorizationController, CredentialManager, navigator.credentials) that require real devices and user interaction. The Dart-testable surface (stub, interface, Pigeon adapter error mapping) is fully automated across 26 tests.

---

## Validation Audit 2026-03-10

| Metric | Count |
|--------|-------|
| Gaps found | 1 |
| Resolved | 1 |
| Escalated | 0 |

Gap resolved: Created `webauthn_credential_platform_stub_test.dart` (6 tests) to cover the stub platform behavior, which was the only Dart-testable gap without existing automated tests.

---

## Re-Audit 2026-03-11

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 3 |
| Escalated | 0 |

### Root Cause

The `amplify_auth_cognito_dart` package resolves `amplify_core` to the published pub.dev version (2.10.1), not the local workspace source. The published version does not contain the Phase 1 passkey types (`PasskeyNotSupportedException`, `AuthWebAuthnCredential`, etc.), causing compilation failure for all test files.

### Resolution Applied

Created `packages/auth/amplify_auth_cognito_dart/pubspec_overrides.yaml` with local path override:
```yaml
dependency_overrides:
  amplify_core:
    path: ../../amplify_core
```

This is the standard Dart mono-repo mechanism for local development. After applying:
- `dart pub get` resolves `amplify_core` to local source with Phase 1 types
- All 11 tests compile and pass (6 stub + 5 interface)
- Test execution time: ~5 seconds

### Gaps Resolved

| Gap ID | Task ID | Requirement | Resolution |
|--------|---------|-------------|------------|
| GAP-01 | 03-01-01 | PLAT-08 (stub error behavior) | pubspec_overrides.yaml unblocks compilation; 6/6 tests green |
| GAP-02 | 03-01-02 | PLAT-08 (interface contract) | pubspec_overrides.yaml unblocks compilation; 5/5 tests green |
| GAP-03 | 03-01-03 | PLAT-08 (Pigeon adapter error mapping) | Flutter SDK available; created pigeon_webauthn_credential_platform_test.dart; 15/15 tests green |

### Remaining Manual-Only Items

- Native platform bridges (PLAT-01, PLAT-02, PLAT-04): Require device runtimes -- verified via code review in VERIFICATION.md

---

## Validation Sign-Off

- [x] All tasks have automated verify or documented manual verification
- [x] Sampling continuity: automated tests cover every wave with no gaps
- [x] Wave 0 covers all MISSING references (stub test + interface test)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (Dart tests, with pubspec_overrides.yaml)
- [x] `nyquist_compliant: true` set in frontmatter
- [x] pubspec_overrides.yaml required for local development (mono-repo constraint)

**Approval:** re-approved 2026-03-11 (pubspec_overrides.yaml unblocked 11 Dart tests + 15 new Flutter Pigeon adapter tests = 26 total)

---
*Created: 2026-03-09*
*Audited: 2026-03-10*
*Re-audited: 2026-03-11*
*Auditor: Claude (gsd-validate-phase)*

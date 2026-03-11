# Retrospective

## Milestone: v1.0 -- Passkey Support

**Shipped:** 2026-03-11
**Phases:** 6 | **Plans:** 21 | **Timeline:** 5 days

### What Was Built

- Foundation layer: WebAuthn types, base64url serde, PasskeyException hierarchy, raw Cognito HTTP clients
- Sign-in flow: State machine WEB_AUTHN challenge handling with automatic assertion and two-step SELECT_CHALLENGE
- Platform bridges: iOS (ASAuthorizationController), Android (CredentialManager), Web (navigator.credentials)
- Desktop bridges: macOS (shared Darwin), Windows (Windows Hello FFI), Linux (libfido2 FFI)
- Credential management: associate, list, delete passkeys with pagination and auth protection
- Authenticator UI: Challenge selection, passkey ceremony, configurable registration prompt

### What Worked

- Phased architecture (foundation -> flow -> bridges -> management -> UI) kept each phase focused and buildable
- JSON string boundary pattern for platform bridges minimized per-platform complexity
- Pigeon code generation for iOS/Android/macOS bridges provided type-safe native interop
- Wave 0 test infrastructure (Phase 5 plan 00) established mocks before implementation
- Dual-package pattern (pure Dart core + Flutter wrapper) kept Cognito logic testable without platform dependencies

### What Was Inefficient

- Phase 5 Plan 00 (test infrastructure) took 59 minutes -- duck-typing approach for mocks was replaced by interface implementation later
- Phase 5 Plan 02 took 81 minutes -- HTTP mocking complexity for Cognito API tests
- ROADMAP.md traceability table had formatting inconsistencies (mixed column counts) that persisted through milestone

### Patterns Established

- Abstract interface class with JSON string boundary for platform bridges
- Pigeon bridge + Dart adapter + error code mapping pattern for iOS/Android/macOS
- FFI bridge with graceful fallback pattern for Windows/Linux
- Auto-responding challenge handler pattern (no hasUserResponse guard)
- Dependency manager get<T>() with null check for retrieving platform bridges

### Key Lessons

- Windows/Linux FFI bridges are viable for WebAuthn but require different patterns (raw pointer offsets vs Struct subclasses)
- libfido2 FFI requires manual W3C WebAuthn response JSON assembly from getter functions
- Pigeon error propagation differs between platforms (PigeonError on iOS/macOS, FlutterError on Android)
- Test infrastructure phase (Wave 0) pays off even when initial approach needs revision

### Cost Observations

- Sessions: ~10 sessions across 5 days
- Most plans completed in 2-5 minutes; outliers were test infrastructure (59min, 81min)
- 77 commits for planning/execution artifacts

---

## Cross-Milestone Trends

| Metric | v1.0 |
|--------|------|
| Phases | 6 |
| Plans | 21 |
| Files Changed | 153 |
| LOC Added | +24,321 |
| Tests | 93 |
| Requirements | 23/23 |
| Timeline | 5 days |

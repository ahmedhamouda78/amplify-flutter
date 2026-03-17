# Roadmap: Amplify Flutter Passkey Support

## Milestones

- **v1.0 Passkey Support** -- Phases 1-6 (shipped 2026-03-11) | [Archive](milestones/v1.0-ROADMAP.md)

## Phases

<details>
<summary>v1.0 Passkey Support (Phases 1-6) -- SHIPPED 2026-03-11</summary>

- [x] Phase 1: Foundation -- Types, Serde, and Cognito API Clients (5/5 plans) -- completed 2026-03-07
- [x] Phase 2: Sign-In Flow -- State Machine WEB_AUTHN Integration (3/3 plans) -- completed 2026-03-08
- [x] Phase 3: Platform Bridges -- iOS, Android, and Web (4/4 plans) -- completed 2026-03-09
- [x] Phase 4: Platform Bridges -- macOS, Windows, and Linux (3/3 plans) -- completed 2026-03-09
- [x] Phase 5: Credential Management -- Register, List, Delete APIs (3/3 plans) -- completed 2026-03-10
- [x] Phase 6: Authenticator UI -- Passkey Screens and Flows (3/3 plans) -- completed 2026-03-10

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|---------------|--------|-----------|
| 1. Foundation | v1.0 | 5/5 | Complete | 2026-03-07 |
| 2. Sign-In Flow | v1.0 | 3/3 | Complete | 2026-03-08 |
| 3. iOS/Android/Web Bridges | v1.0 | 4/4 | Complete | 2026-03-09 |
| 4. macOS/Windows/Linux Bridges | v1.0 | 3/3 | Complete | 2026-03-09 |
| 5. Credential Management | v1.0 | 3/3 | Complete | 2026-03-10 |
| 6. Authenticator UI | v1.0 | 3/3 | Complete | 2026-03-10 |

### Phase 1: Passkey e2e integration tests — stub platform bridge, add sign-in and registration test coverage

**Goal:** End-to-end integration tests for passkey sign-in and registration flows using a real Cognito backend with a stubbed WebAuthn platform bridge, covering happy paths, error scenarios, first-factor selection, and isPasskeySupported.
**Requirements**: SIGN-IN-01, SIGN-IN-02, SIGN-IN-03, SIGN-IN-04, REG-01, REG-02, REG-03, REG-04, SELECT-01, SUPPORT-01
**Depends on:** v1.0 Passkey Support (shipped)
**Plans:** 3 plans

Plans:
- [ ] 01-01-PLAN.md — Test infrastructure: modify AmplifyAuthTestPlugin for WebAuthn injection, add environment, create shared utilities
- [ ] 01-02-PLAN.md — WebAuthn sign-in tests: happy path, cancel, unsupported, invalid credential, first-factor selection
- [ ] 01-03-PLAN.md — WebAuthn registration tests: happy path, cancel, unsupported, duplicate, isPasskeySupported

---
*Roadmap created: 2026-03-07*

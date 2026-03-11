# Milestones

## v1.0 Passkey Support (Shipped: 2026-03-11)

**Phases completed:** 6 phases, 21 plans | 153 files changed, +24,321 LOC | 93 tests passing
**Timeline:** 2026-03-07 to 2026-03-11 (5 days)

**Delivered:** Full WebAuthn/passkey support for amplify-flutter across all six platforms (iOS, Android, macOS, Web, Windows, Linux) with credential management APIs and Authenticator UI integration.

**Key accomplishments:**
- Foundation layer: WebAuthn types, base64url serde, PasskeyException hierarchy, raw Cognito HTTP clients (4 operations)
- Sign-in flow: State machine WEB_AUTHN challenge handling with automatic assertion and SELECT_CHALLENGE two-step flow
- Platform bridges: iOS (ASAuthorizationController), Android (CredentialManager), Web (navigator.credentials) via Pigeon
- Desktop bridges: macOS (shared Darwin), Windows (Windows Hello FFI), Linux (libfido2 FFI with graceful fallback)
- Credential management: associate, list, delete passkeys with pagination, auth protection, and test infrastructure
- Authenticator UI: Challenge selection screen, passkey ceremony flow, configurable registration prompt with localization

**Requirements:** 23/23 satisfied (AUTH: 6, FLOW: 5, PLAT: 8, UI: 4)

**Archives:**
- [Roadmap](milestones/v1.0-ROADMAP.md)
- [Requirements](milestones/v1.0-REQUIREMENTS.md)
- [Audit](milestones/v1.0-MILESTONE-AUDIT.md)

---


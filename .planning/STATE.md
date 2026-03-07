# Project State

## Current Position

Phase: 1 (not started)
Plan: —
Status: Roadmap complete, ready to plan Phase 1
Last activity: 2026-03-07 — Milestone v1.0 roadmap created

## Accumulated Context

- Project uses dual-package pattern: pure Dart core + Flutter wrapper with Pigeon bridges
- Cognito SDK already has WEB_AUTHN/USER_AUTH/SELECT_CHALLENGE enum values but no application logic
- AuthFactorType.webAuthn is commented out with TODO
- WebAuthn registration APIs (Start/Complete) not in Smithy-generated SDK — will use raw HTTP
- Both amplify-swift and amplify-android use identical state machine pattern for WebAuthn
- SELECT_CHALLENGE + WEB_AUTHN is a two-step flow (answer first, then ceremony)
- Platform bridge should be minimal: createCredential, getCredential, isPasskeySupported
- iOS/macOS share Darwin implementation via ASAuthorizationController
- Android uses androidx.credentials.CredentialManager
- Web uses navigator.credentials via JS interop

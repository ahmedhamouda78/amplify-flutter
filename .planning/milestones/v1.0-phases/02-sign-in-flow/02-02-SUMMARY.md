---
phase: 02-sign-in-flow
plan: 02
subsystem: auth
tags: [dart, webauthn, state-machine, sign-in, passkey, assertion]

# Dependency graph
requires: [02-01]
provides:
  - ChallengeNameType.webAuthn case in createRespondToAuthChallengeRequest() (auto-responding)
  - createWebAuthnAssertionRequest() method for WEB_AUTHN challenge handling
  - SELECT_CHALLENGE -> WEB_AUTHN two-step flow support
affects: [02-03, 03-platform-bridges]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Auto-responding challenge handler (no hasUserResponse guard) with platform bridge invocation"
    - "Dependency manager get<T>() pattern for retrieving platform bridge with null check"

key-files:
  created: []
  modified:
    - packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart

key-decisions:
  - "WebAuthnCredentialPlatform retrieved via dependency manager get<T>() with null check"
  - "Two-step SELECT_CHALLENGE -> WEB_AUTHN works automatically (no special code needed)"

patterns-established:
  - "WebAuthn assertion follows same create*Request pattern as other challenge handlers"
  - "Platform bridge errors (PasskeyNotSupportedException, PasskeyAssertionFailedException) propagate as sign-in failures"

requirements-completed: [FLOW-01, FLOW-03, AUTH-01]

# Metrics
duration: 3min
completed: 2026-03-07
---

# Phase 2 Plan 02: Add WEB_AUTHN Challenge Handler to Sign-In State Machine Summary

**Implemented createWebAuthnAssertionRequest() in sign-in state machine with platform bridge invocation and auto-responding challenge flow**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-07
- **Completed:** 2026-03-07
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments
- Added `ChallengeNameType.webAuthn` case to `createRespondToAuthChallengeRequest()` switch (no `hasUserResponse` guard — auto-responds)
- Created `createWebAuthnAssertionRequest()` method that:
  - Extracts `CREDENTIAL_REQUEST_OPTIONS` from challenge parameters
  - Retrieves `WebAuthnCredentialPlatform` from dependency manager with null check
  - Calls `platform.getCredential(optionsJson)` for the assertion ceremony
  - Builds `RespondToAuthChallengeRequest` with `CREDENTIAL` response
- Verified SELECT_CHALLENGE -> WEB_AUTHN two-step flow works automatically via existing `_processChallenge()` recursion
- Added appropriate error handling: `PasskeyAssertionFailedException` for missing options, `PasskeyNotSupportedException` for missing bridge

## Task Commits

All tasks committed atomically in:

1. **Tasks 1-3: Add webAuthn challenge handler and verify two-step flow** - `f626973` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart` - Added webAuthn case and createWebAuthnAssertionRequest() method (+37 lines)

## Decisions Made
- WEB_AUTHN has no `when hasUserResponse` guard — it auto-responds like `passwordVerifier` and `deviceSrpAuth`
- Platform bridge retrieved via `get<WebAuthnCredentialPlatform>()` — returns null if not registered (no hard dependency)
- Two-step flow needs no special code: SELECT_CHALLENGE answer triggers WEB_AUTHN challenge which auto-responds on recursion

## Deviations from Plan

None — plan executed as written.

## Issues Encountered
None

## Next Phase Readiness
- Sign-in state machine fully handles WEB_AUTHN challenges
- Platform bridges (Phase 3) just need to register `WebAuthnCredentialPlatform` implementation via dependency manager
- The `getCredential()` contract is established: takes JSON options string, returns JSON credential string

---
*Phase: 02-sign-in-flow*
*Completed: 2026-03-07*

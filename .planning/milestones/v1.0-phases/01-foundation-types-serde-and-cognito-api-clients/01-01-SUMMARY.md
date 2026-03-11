---
phase: 01-foundation-types-serde-and-cognito-api-clients
plan: 01
subsystem: auth
tags: [dart, enum, webauthn, passkey, cognito, serde]

# Dependency graph
requires: []
provides:
  - AuthFactorType.webAuthn enum value with @JsonValue('WEB_AUTHN') annotation
  - ChallengeNameType.webAuthn handling in SDK bridge (temporary InvalidStateException)
affects: [02-sign-in-flow, 05-credential-management]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Enum value with string constructor and @JsonValue annotation for JSON serde"
    - "InvalidStateException placeholder for unimplemented challenge handling"

key-files:
  created: []
  modified:
    - packages/amplify_core/lib/src/types/auth/sign_in/auth_factor_type.dart
    - packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart

key-decisions:
  - "webAuthn bridge case throws InvalidStateException as placeholder until Phase 2 implements full ceremony"

patterns-established:
  - "Challenge type bridge pattern: map ChallengeNameType to AuthSignInStep or throw InvalidStateException"

requirements-completed: [FLOW-04]

# Metrics
duration: 2min
completed: 2026-03-07
---

# Phase 1 Plan 01: Uncomment and Enable AuthFactorType.webAuthn Summary

**AuthFactorType.webAuthn enum value enabled with WEB_AUTHN JSON serde and temporary bridge exception for challenge handling**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-07T14:45:00Z
- **Completed:** 2026-03-07T14:47:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Uncommented AuthFactorType.webAuthn enum value with @JsonValue('WEB_AUTHN') annotation
- Added ChallengeNameType.webAuthn case to ChallengeNameTypeBridge with InvalidStateException placeholder
- Removed TODO(cadivus) comment block referencing passwordless authenticator

## Task Commits

Each task was committed atomically:

1. **Task 1: Uncomment webAuthn in AuthFactorType enum** - `b36de05` (feat)
2. **Task 2: Add webAuthn handling in ChallengeNameTypeBridge** - `f4a6769` (feat)

## Files Created/Modified
- `packages/amplify_core/lib/src/types/auth/sign_in/auth_factor_type.dart` - Added webAuthn enum value as fifth AuthFactorType entry
- `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart` - Added ChallengeNameType.webAuthn case before wildcard catch-all

## Decisions Made
- webAuthn bridge case throws InvalidStateException as a temporary placeholder, to be replaced in Phase 2 with actual WEB_AUTHN challenge ceremony handling

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- AuthFactorType.webAuthn is available in the type system for all downstream phases
- ChallengeNameType.webAuthn is explicitly handled (not falling through to catch-all)
- Phase 2 can replace the InvalidStateException with actual WebAuthn ceremony logic
- The _allowedFirstFactorTypes getter will now automatically include webAuthn when ChallengeNameType.webAuthn appears in availableChallenges

---
*Phase: 01-foundation-types-serde-and-cognito-api-clients*
*Completed: 2026-03-07*

## Self-Check: PASSED
- auth_factor_type.dart: FOUND
- sdk_bridge.dart: FOUND
- Commit b36de05: FOUND
- Commit f4a6769: FOUND

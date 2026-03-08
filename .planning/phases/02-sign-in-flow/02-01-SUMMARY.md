---
phase: 02-sign-in-flow
plan: 01
subsystem: auth
tags: [dart, webauthn, cognito, constants, sdk-bridge, challenge]

# Dependency graph
requires: [01-01]
provides:
  - CognitoConstants.challengeParamCredentialRequestOptions constant
  - CognitoConstants.challengeParamCredential constant
  - ChallengeNameType.webAuthn mapped to AuthSignInStep.confirmSignInWithCustomChallenge
affects: [02-02, 02-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Auto-responding challenge type mapped to confirmSignInWithCustomChallenge (transient step)"

key-files:
  created: []
  modified:
    - packages/auth/amplify_auth_cognito_dart/lib/src/flows/constants.dart
    - packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart

key-decisions:
  - "ChallengeNameType.webAuthn maps to AuthSignInStep.confirmSignInWithCustomChallenge (transient)"
  - "WEB_AUTHN is auto-responding challenge (no hasUserResponse guard) — like passwordVerifier"

patterns-established:
  - "WebAuthn challenge parameter constants follow existing challengeParam* naming convention"

requirements-completed: [FLOW-02]

# Metrics
duration: 2min
completed: 2026-03-07
---

# Phase 2 Plan 01: Add WebAuthn Constants and Update SDK Bridge Summary

**Added CREDENTIAL_REQUEST_OPTIONS and CREDENTIAL constants, replaced InvalidStateException placeholder with proper signInStep mapping**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-07
- **Completed:** 2026-03-07
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `CognitoConstants.challengeParamCredentialRequestOptions` with value `'CREDENTIAL_REQUEST_OPTIONS'`
- Added `CognitoConstants.challengeParamCredential` with value `'CREDENTIAL'`
- Replaced `InvalidStateException` placeholder in `ChallengeNameTypeBridge.signInStep` with `AuthSignInStep.confirmSignInWithCustomChallenge`

## Task Commits

All tasks committed atomically in:

1. **Task 1 & 2: Add constants and update SDK bridge** - `f626973` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito_dart/lib/src/flows/constants.dart` - Added two WebAuthn challenge parameter constants
- `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/sdk_bridge.dart` - Replaced InvalidStateException with confirmSignInWithCustomChallenge mapping

## Decisions Made
- WEB_AUTHN is an auto-responding challenge — the state machine handles it internally without yielding to user
- Using `confirmSignInWithCustomChallenge` avoids adding a new `AuthSignInStep` enum value (which would be invasive across amplify_core)

## Deviations from Plan

None — plan executed as written.

## Issues Encountered
None

## Next Phase Readiness
- Constants are available for Plan 02 (state machine) to reference when extracting/sending challenge parameters
- SDK bridge no longer throws on WEB_AUTHN challenges, unblocking sign-in flow

---
*Phase: 02-sign-in-flow*
*Completed: 2026-03-07*

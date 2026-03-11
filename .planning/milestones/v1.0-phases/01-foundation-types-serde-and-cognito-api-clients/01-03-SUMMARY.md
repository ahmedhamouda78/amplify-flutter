---
phase: 01-foundation-types-serde-and-cognito-api-clients
plan: 03
subsystem: auth
tags: [passkey, webauthn, exception, dart]

# Dependency graph
requires: []
provides:
  - PasskeyException hierarchy (6 exception types for passkey operations)
  - Typed error handling for passkey not supported, cancelled, registration failed, assertion failed, RP mismatch
affects: [02-cognito-srp-passkey-ceremony, 03-platform-bridge]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Passkey exceptions follow existing AuthException sealed class hierarchy pattern"
    - "Part-file pattern for exception grouping under amplify_exception.dart"

key-files:
  created:
    - packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart
  modified:
    - packages/amplify_core/lib/src/types/exception/amplify_exception.dart

key-decisions:
  - "Passkey exceptions extend AuthException via PasskeyException base, not directly"
  - "Each subtype overrides runtimeTypeName for AWSDebuggable mixin compatibility"
  - "Default recovery suggestions baked into each subtype via super parameter defaults"

patterns-established:
  - "PasskeyException subtypes use default recoverySuggestion parameter values"

requirements-completed: [AUTH-06]

# Metrics
duration: 2min
completed: 2026-03-07
---

# Phase 1 Plan 03: PasskeyException Hierarchy Summary

**Typed PasskeyException hierarchy with 6 exception classes for passkey/WebAuthn error handling**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-07T14:46:44Z
- **Completed:** 2026-03-07T14:48:11Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Created PasskeyException base class extending AuthException
- Added five specific subtypes: NotSupported, Cancelled, RegistrationFailed, AssertionFailed, RpMismatch
- Each subtype includes default recovery suggestion and runtimeTypeName override
- All types transitively exported via amplify_core barrel file

## Task Commits

Each task was committed atomically:

1. **Tasks 1-2: Create PasskeyException hierarchy + Register part directive** - `628b597` (feat)
2. **Task 3: Verify barrel export** - No commit needed (transitive export via part file, verified)

## Files Created/Modified
- `packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart` - PasskeyException base and 5 subtypes
- `packages/amplify_core/lib/src/types/exception/amplify_exception.dart` - Added part directive for passkey_exception.dart

## Decisions Made
- Passkey exceptions extend AuthException via an intermediate PasskeyException base class, allowing catch blocks to handle all passkey errors generically or specifically
- Each subtype overrides runtimeTypeName (consistent with existing exception pattern, e.g. AuthServiceException)
- Default recovery suggestions provided as parameter defaults rather than hardcoded in constructor body

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Dart SDK not available in execution environment; static analysis verification skipped. Code reviewed structurally.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- PasskeyException hierarchy ready for use in Cognito SRP/passkey ceremony implementation
- Exception types can be thrown from platform bridge error handling

---
*Phase: 01-foundation-types-serde-and-cognito-api-clients*
*Completed: 2026-03-07*

---
phase: 01-passkey-e2e-integration-tests-stub-platform-bridge-add-sign-in-and-registration-test-coverage
plan: 01
subsystem: testing
tags: [webauthn, passkey, integration-test, mock, amplify-auth]

# Dependency graph
requires:
  - phase: main (passkey feature implementation)
    provides: WebAuthnCredentialPlatform interface and exception types
provides:
  - AmplifyAuthTestPlugin with WebAuthn platform injection capability
  - webAuthnEnvironment constant for test configuration
  - MockWebAuthnCredentialPlatform with factory functions for common scenarios
  - Test credential fixtures (testCredentialResponse, testRegistrationResponse)
affects: [passkey-sign-in-tests, passkey-registration-tests, webauthn-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Test plugin extension pattern for platform mock injection
    - Factory functions for mock scenario configurations

key-files:
  created:
    - packages/test/amplify_auth_integration_test/lib/src/webauthn_test_utils.dart
  modified:
    - packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart
    - packages/test/amplify_auth_integration_test/lib/src/environments.dart
    - packages/test/amplify_auth_integration_test/lib/amplify_auth_integration_test.dart

key-decisions:
  - "Copied MockWebAuthnCredentialPlatform class directly instead of adding amplify_auth_cognito_test dependency to avoid build complexity"
  - "Override addPlugin to inject mock after super call, leveraging addInstance replacement behavior"

patterns-established:
  - "Pattern 1: Test plugins override addPlugin to inject mocks into state machine after super initialization"
  - "Pattern 2: Factory functions provide pre-configured mocks for common test scenarios (success, cancelled, unsupported)"

requirements-completed: [SIGN-IN-01, SIGN-IN-02, SIGN-IN-03, SIGN-IN-04, REG-01, REG-02, REG-03, REG-04, SELECT-01, SUPPORT-01]

# Metrics
duration: 2min
completed: 2026-03-17
---

# Phase 01 Plan 01: Shared WebAuthn Test Infrastructure Summary

**AmplifyAuthTestPlugin extended with WebAuthn mock injection, webauthn environment constant, and shared test utilities with factory functions for success/cancelled/unsupported scenarios**

## Performance

- **Duration:** 2 min 1 sec
- **Started:** 2026-03-17T21:49:53Z
- **Completed:** 2026-03-17T21:51:54Z
- **Tasks:** 2
- **Files modified:** 4 (3 modified, 1 created)

## Accomplishments
- AmplifyAuthTestPlugin accepts optional WebAuthnCredentialPlatform parameter and injects it into state machine
- webAuthnEnvironment constant defined for test configuration matching deployed backend
- Shared test utilities with MockWebAuthnCredentialPlatform and credential fixtures ready for integration tests
- Factory functions provide pre-configured mocks for success, cancellation, and unsupported scenarios

## Task Commits

Each task was committed atomically:

1. **Task 1: Modify AmplifyAuthTestPlugin to support WebAuthn platform injection and add webauthn environment** - `c213c145d` (feat)
2. **Task 2: Create shared webauthn test utilities and update barrel export** - `cb4a962c2` (feat)

## Files Created/Modified
- `packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart` - Added WebAuthnCredentialPlatform? parameter and addPlugin override for mock injection
- `packages/test/amplify_auth_integration_test/lib/src/environments.dart` - Added webAuthnEnvironment constant with Gen2 defaults
- `packages/test/amplify_auth_integration_test/lib/src/webauthn_test_utils.dart` - Created with MockWebAuthnCredentialPlatform, test fixtures, and factory functions
- `packages/test/amplify_auth_integration_test/lib/amplify_auth_integration_test.dart` - Added barrel export for webauthn_test_utils

## Decisions Made
- **Copied MockWebAuthnCredentialPlatform directly:** Instead of adding amplify_auth_cognito_test as a dependency (which could affect build configuration), copied the ~48-line MockWebAuthnCredentialPlatform class directly into webauthn_test_utils.dart. This keeps the integration test package self-contained.
- **Override addPlugin with post-super injection:** The AmplifyAuthCognito.addPlugin method sets up platform bridges after calling super. By calling super.addPlugin() first then injecting our mock, we leverage addInstance's replacement behavior to overwrite the platform bridge cleanly.
- **Test fixtures from unit tests:** Used testCredentialResponse and testRegistrationResponse constants directly from sign_in_webauthn_test.dart since they are known to work with Cognito validation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Shared test infrastructure complete and ready for use
- Passkey sign-in integration tests can now import MockWebAuthnCredentialPlatform and factory functions
- Passkey registration integration tests can use the same utilities
- webAuthnEnvironment constant available for test runner configuration

---
*Phase: 01-passkey-e2e-integration-tests-stub-platform-bridge-add-sign-in-and-registration-test-coverage*
*Plan: 01*
*Completed: 2026-03-17*

## Self-Check: PASSED

All files and commits verified:
- Created: packages/test/amplify_auth_integration_test/lib/src/webauthn_test_utils.dart ✓
- Commit c213c145d (Task 1) ✓
- Commit cb4a962c2 (Task 2) ✓

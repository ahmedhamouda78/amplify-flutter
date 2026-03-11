---
phase: 01-foundation-types-serde-and-cognito-api-clients
plan: 05
subsystem: auth
tags: [cognito, webauthn, passkey, http-client, aws-json-1.1]

# Dependency graph
requires:
  - phase: 01-foundation-types-serde-and-cognito-api-clients
    provides: WebAuthn JSON serialization types (PasskeyCreateOptions, PasskeyCreateResult)
provides:
  - CognitoWebAuthnClient for raw HTTP calls to Cognito WebAuthn APIs
  - StartWebAuthnRegistration, CompleteWebAuthnRegistration, ListWebAuthnCredentials, DeleteWebAuthnCredential
  - ListWebAuthnCredentialsResult and WebAuthnCredentialDescription types
affects: [02-state-machine-and-platform-bridge, 03-platform-implementations]

# Tech tracking
tech-stack:
  added: []
  patterns: [raw HTTP client for non-Smithy Cognito operations, AWS JSON 1.1 protocol]

key-files:
  created:
    - packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart
  modified:
    - packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart

key-decisions:
  - "Used raw HTTP with AWS JSON 1.1 protocol instead of Smithy since WebAuthn ops are not in generated SDK"
  - "WebAuthn-specific error types mapped to UnknownServiceException with recovery suggestions rather than new exception classes"
  - "CreatedAt parsed as Unix timestamp (seconds) from Cognito, converted to DateTime"

patterns-established:
  - "Raw HTTP Cognito client pattern: CognitoWebAuthnClient with _makeRequest helper for non-Smithy operations"
  - "Error mapping pattern: __type field parsed and mapped to CognitoServiceException subtypes"

requirements-completed: [FLOW-05]

# Metrics
duration: 3min
completed: 2026-03-07
---

# Phase 1 Plan 5: Raw HTTP Cognito WebAuthn API Clients Summary

**Raw HTTP CognitoWebAuthnClient implementing four WebAuthn registration/management operations using AWS JSON 1.1 protocol**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-07T14:54:57Z
- **Completed:** 2026-03-07T14:58:00Z
- **Tasks:** 6
- **Files modified:** 2

## Accomplishments
- CognitoWebAuthnClient class with region, httpClient, and optional endpoint configuration
- All four Cognito WebAuthn API operations: Start/CompleteWebAuthnRegistration, List/DeleteWebAuthnCredentials
- Error response handling mapping Cognito __type to typed CognitoServiceException subtypes
- ListWebAuthnCredentialsResult and WebAuthnCredentialDescription types with pagination support

## Task Commits

Each task was committed atomically:

1. **Tasks 1-5: CognitoWebAuthnClient class and all four operations** - `757aaae` (feat)
2. **Task 6: Export from barrel file** - `8c70d28` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart` - Raw HTTP client for Cognito WebAuthn API operations with StartWebAuthnRegistration, CompleteWebAuthnRegistration, ListWebAuthnCredentials, DeleteWebAuthnCredential, and supporting types
- `packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart` - Added export for cognito_webauthn_client.dart

## Decisions Made
- Used raw HTTP with AWS JSON 1.1 protocol (Content-Type: application/x-amz-json-1.1, X-Amz-Target header) since WebAuthn operations are not in the Smithy-generated SDK
- Mapped WebAuthn-specific error types (WebAuthnNotEnabledException, etc.) to UnknownServiceException with descriptive recovery suggestions, rather than creating new exception subclasses -- keeps the exception hierarchy clean while still providing actionable error info
- Parsed CreatedAt from Cognito as Unix timestamp in seconds, converting to DateTime via millisecondsSinceEpoch

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- CognitoWebAuthnClient is ready for use by the state machine in Phase 2
- All four WebAuthn registration/management operations are available
- Error handling follows existing project patterns with CognitoServiceException subtypes

---
*Phase: 01-foundation-types-serde-and-cognito-api-clients*
*Completed: 2026-03-07*

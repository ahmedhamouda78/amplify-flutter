# Phase 1: Passkey e2e integration tests - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

End-to-end integration tests for passkey sign-in and registration flows. Tests use a real Cognito backend with WebAuthn enabled but stub the platform bridge (since CI cannot invoke real biometric authenticators). Covers sign-in, registration, first-factor selection, and error scenarios.

</domain>

<decisions>
## Implementation Decisions

### Stub strategy
- Extend existing `MockWebAuthnCredentialPlatform` (callback-based pattern) -- do NOT build a stateful fake or record/replay system
- Callbacks return instantly -- no simulated delays
- Real Cognito backend + stubbed platform bridge -- matches the existing integration test pattern where tests hit deployed backends
- Integration tests only -- existing unit tests in `amplify_auth_cognito_test` already cover mocked Cognito client layer for webauthn flows

### Test flow coverage
- **Sign-in:** Happy path (full flow through Cognito WEB_AUTHN challenge) + error cases (user cancels, passkey not supported, invalid credential response)
- **Registration:** Happy path (StartWebAuthnRegistration + CompleteWebAuthnRegistration) + error cases (user cancels, platform unsupported, already-registered credential)
- **First-factor selection:** Test the SELECT_CHALLENGE / continueSignInWithFirstFactorSelection path when user has both password and passkey
- **isPasskeySupported:** Basic sanity check that stub returns expected values based on configuration

### Test location & infrastructure
- Tests live in `packages/auth/amplify_auth_cognito/example/integration_test/` alongside existing integration tests (flat file convention)
- Inject stub via TestAuthPlugin override -- configure TestAuthPlugin to inject MockWebAuthnCredentialPlatform into the plugin's dependency graph
- Shared utilities (stub setup, test credential JSON fixtures) go in `packages/test/amplify_auth_integration_test/lib/src/` for reusability

### Backend & environment
- Use existing `infra-gen2/backends/auth/webauthn/` backend (email + phone OTP login, webAuthn: true, preferredChallenge: WEB_AUTHN)
- Add EnvironmentInfo entry matching the existing pattern used by MFA and sign-in tests
- User setup: create user with email + password via admin API, sign in, register passkey, then test passkey sign-in
- Clean up (delete test users) in tearDown after each test -- matches existing auth integration test pattern

### Claude's Discretion
- Exact test file naming conventions (follow existing patterns)
- Test credential JSON fixture content (realistic but not production values)
- How TestAuthPlugin override is structured internally
- Whether to group all passkey tests in one file or split sign-in/registration/first-factor-selection

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing test infrastructure
- `packages/test/amplify_auth_integration_test/lib/src/test_runner.dart` -- EnvironmentInfo, testRunner.configure(), test lifecycle pattern
- `packages/test/amplify_auth_integration_test/lib/src/environments.dart` -- How environment entries are defined (Gen1/Gen2 defaults, MFA config)
- `packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart` -- TestAuthPlugin used by integration tests

### Existing passkey test patterns
- `packages/auth/amplify_auth_cognito_test/lib/common/mock_webauthn.dart` -- MockWebAuthnCredentialPlatform callback pattern to extend
- `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` -- WebAuthn sign-in state machine test with mock credential fixtures
- `packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart` -- Registration test pattern with mock clients

### Platform bridge interface
- `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart` -- Interface that stub implements
- `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform_stub.dart` -- Existing stub for unsupported platforms

### Backend configuration
- `infra-gen2/backends/auth/webauthn/amplify/auth/resource.ts` -- Cognito backend config with webAuthn enabled

### Example integration tests (pattern reference)
- `packages/auth/amplify_auth_cognito/example/integration_test/sign_in_sign_out_test.dart` -- Sign-in integration test pattern
- `packages/auth/amplify_auth_cognito/example/integration_test/mfa_sms_test.dart` -- MFA integration test pattern (closest analog to passkey flow)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MockWebAuthnCredentialPlatform` in `amplify_auth_cognito_test`: callback-based mock with createCredential, getCredential, isPasskeySupported -- extend for integration tests
- `testRunner` in `amplify_auth_integration_test`: handles configure, setUp, tearDown lifecycle for integration tests
- `EnvironmentInfo` class: structured environment config with Gen1/Gen2 defaults pattern
- Test credential JSON fixtures in `sign_in_webauthn_test.dart`: `testCredentialRequestOptions` and `testCredentialResponse` constants

### Established Patterns
- Integration tests use `testRunner.configure(environmentName: 'xxx')` to select backend
- Each test creates fresh users via admin API, cleans up in tearDown
- Mock clients use callback pattern (optional functions, throw UnimplementedError if not set)
- Dual mock exists: `mock_webauthn.dart` in test package + inline mock in `sign_in_webauthn_test.dart`

### Integration Points
- `TestAuthPlugin` -- injection point for overriding plugin dependencies in integration tests
- `CognitoAuthStateMachine.addInstance()` -- dependency injection at state machine level (used in unit tests)
- `amplify_auth_integration_test` exports -- entry point for shared test utilities

</code_context>

<specifics>
## Specific Ideas

- Match exactly what existing e2e tests do for environment setup, user creation, and cleanup
- Follow the existing flat-file convention in `integration_test/` directory
- Stub must work with the real Cognito challenge/response flow -- mock returns JSON that Cognito accepts

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 01-passkey-e2e-integration-tests-stub-platform-bridge-add-sign-in-and-registration-test-coverage*
*Context gathered: 2026-03-17*

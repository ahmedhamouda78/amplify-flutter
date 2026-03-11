# Phase 5: Credential Management — Register, List, Delete APIs - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Expose high-level passkey credential management APIs that orchestrate Cognito calls and platform ceremonies. Four public methods: `associateWebAuthnCredential()` (registration), `listWebAuthnCredentials()` (list), `deleteWebAuthnCredential()` (delete), and `isPasskeySupported()` (capability check). All low-level Cognito API clients and platform bridges are already built in Phases 1-4.

</domain>

<decisions>
## Implementation Decisions

### API Surface Placement
- All 4 methods added to **generic `AuthPluginInterface`** in `amplify_core` with default `throw UnimplementedError` stubs
- Corresponding methods added to **`AuthCategory`** so users call `Amplify.Auth.associateWebAuthnCredential()` etc.
- **Cognito-specific overloads** also exposed on `AmplifyAuthCognitoDart` for Cognito-specific result types (like CognitoSignInResult pattern)
- `associateWebAuthnCredential()` takes **no options parameter** — simple void call
- `deleteWebAuthnCredential()` takes **`String credentialId`** parameter (not a credential object)

### Public Return Types
- **`AuthWebAuthnCredential`** defined in `amplify_core` alongside AuthDevice, AuthUserAttribute
- Includes **all Cognito fields**: credentialId, friendlyName, relyingPartyId, authenticatorAttachment, authenticatorTransports, createdAt
- `associateWebAuthnCredential()` returns **void** — success or throw
- `listWebAuthnCredentials()` returns paginated results — exact pagination pattern at Claude's discretion
- `deleteWebAuthnCredential()` returns **void**
- Cognito-specific result types (e.g., `CognitoListWebAuthnCredentialsResult`) on the Cognito plugin

### Registration Orchestration
- **Single atomic call** — one method does everything: fetch token, StartWebAuthnRegistration, platform ceremony, CompleteWebAuthnRegistration
- No intermediate state exposed to user
- Access token obtained **automatically from current auth session** via `fetchAuthSession` (handles token refresh)
- Orchestration logic lives in **pure Dart core** (`AmplifyAuthCognitoDart` in `amplify_auth_cognito_dart`) — Flutter wrapper inherits
- If any step fails, the whole operation throws

### Error Handling
- **Throw `SignedOutException`** immediately if user is not authenticated (fail fast before Cognito call)
- **`PasskeyCancelledException`** propagates from platform bridge if user cancels ceremony mid-registration
- `isPasskeySupported()` checks **platform capability only** — no network call, no Cognito config check
- `deleteWebAuthnCredential()` **throws if credential not found** — not idempotent
- Cognito service errors (WebAuthnNotEnabled, LimitExceeded, etc.) propagate via existing `CognitoWebAuthnClient` error handling from Phase 1

### Claude's Discretion
- Exact pagination pattern for listWebAuthnCredentials (PaginatedResult vs nextToken)
- Cognito-specific result type details and what extra metadata they expose
- Internal state machine integration details (if needed beyond direct plugin methods)
- Test structure and mock strategies

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CognitoWebAuthnClient`: All 4 Cognito operations implemented (`amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart`)
- `WebAuthnCredentialPlatform` interface: `createCredential`, `getCredential`, `isPasskeySupported` (`amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart`)
- `WebAuthnCredentialDescription`: Internal Cognito response model with `fromJson` — maps to public `AuthWebAuthnCredential`
- `ListWebAuthnCredentialsResult`: Internal pagination result with `nextToken`
- `PasskeyException` hierarchy: 6 typed subtypes ready for error propagation
- `AuthPluginInterface`: Pattern to follow for adding new methods with `throw UnimplementedError` defaults
- `AuthCategory`: Pattern for forwarding to `defaultPlugin` (e.g., `signIn`, `setUpTotp`, `deleteUser`)

### Established Patterns
- Plugin methods delegate via `defaultPlugin.methodName()` in AuthCategory
- Access token retrieval: `fetchAuthSession` returns session with `userPoolTokens.accessToken`
- Cognito-specific overloads: `AmplifyAuthCognitoDart` overrides with Cognito-specific return types
- Dual-package: pure Dart core does logic, Flutter wrapper registers platform bridges in `addPlugin()`

### Integration Points
- `AuthPluginInterface` (`amplify_core/lib/src/plugin/amplify_auth_plugin_interface.dart`): Add 4 new method stubs
- `AuthCategory` (`amplify_core/lib/src/category/amplify_auth_category.dart`): Add 4 forwarding methods
- `AmplifyAuthCognitoDart` (`amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart`): Implement orchestration
- `CognitoWebAuthnClient`: Already built, call from orchestration layer
- `WebAuthnCredentialPlatform`: Retrieved via dependency manager `get<T>()` for createCredential in registration flow

</code_context>

<specifics>
## Specific Ideas

No specific requirements — follow existing Amplify Auth SDK patterns for method signatures, delegation, and error handling.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-credential-management-register-list-delete-apis*
*Context gathered: 2026-03-10*

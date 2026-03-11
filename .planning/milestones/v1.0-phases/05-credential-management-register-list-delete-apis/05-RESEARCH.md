# Phase 5: Credential Management — Register, List, Delete APIs - Research

**Researched:** 2026-03-10
**Domain:** Amplify Flutter plugin API design, Cognito credential orchestration, Dart pagination patterns
**Confidence:** HIGH

## Summary

Phase 5 implements high-level credential management APIs that expose passkey operations to end users via the public Amplify Auth category interface. The research confirms all low-level components (CognitoWebAuthnClient, platform bridges, exception types) are already implemented in Phases 1-4. The primary task is API surface design following established Amplify Flutter patterns.

The Amplify Flutter codebase follows a strict dual-package architecture: pure Dart logic in `amplify_auth_cognito_dart`, with platform-specific bindings registered by the Flutter wrapper `amplify_auth_cognito`. All four methods will follow existing patterns from device management APIs (`fetchDevices`, `deleteDevice`) and MFA APIs (`setUpTotp`), which demonstrate the established orchestration pattern: access token retrieval via `stateMachine.getUserPoolTokens()`, SDK client calls, error propagation, and void/result returns.

**Primary recommendation:** Follow the `fetchDevices` pagination pattern (manual loop with `List<T>` return, not `PaginatedResult<T>`) and the `deleteUser`/`deleteDevice` authentication check pattern (throw `SignedOutException` via failed `getUserPoolTokens()` call). Add generic stubs to `AuthPluginInterface`, forwarding methods to `AuthCategory`, and Cognito-specific implementations in `AmplifyAuthCognitoDart`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- All 4 methods added to **generic `AuthPluginInterface`** in `amplify_core` with default `throw UnimplementedError` stubs
- Corresponding methods added to **`AuthCategory`** so users call `Amplify.Auth.associateWebAuthnCredential()` etc.
- **Cognito-specific overloads** also exposed on `AmplifyAuthCognitoDart` for Cognito-specific result types (like CognitoSignInResult pattern)
- `associateWebAuthnCredential()` takes **no options parameter** — simple void call
- `deleteWebAuthnCredential()` takes **`String credentialId`** parameter (not a credential object)
- **`AuthWebAuthnCredential`** defined in `amplify_core` alongside AuthDevice, AuthUserAttribute
- Includes **all Cognito fields**: credentialId, friendlyName, relyingPartyId, authenticatorAttachment, authenticatorTransports, createdAt
- `associateWebAuthnCredential()` returns **void** — success or throw
- `deleteWebAuthnCredential()` returns **void**
- Cognito-specific result types (e.g., `CognitoListWebAuthnCredentialsResult`) on the Cognito plugin
- **Single atomic call** — one method does everything: fetch token, StartWebAuthnRegistration, platform ceremony, CompleteWebAuthnRegistration
- No intermediate state exposed to user
- Access token obtained **automatically from current auth session** via `fetchAuthSession` (handles token refresh)
- Orchestration logic lives in **pure Dart core** (`AmplifyAuthCognitoDart` in `amplify_auth_cognito_dart`) — Flutter wrapper inherits
- If any step fails, the whole operation throws
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
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-02 | User can register a new passkey on their account (post-authentication) via `associateWebAuthnCredential()` which calls `StartWebAuthnRegistration`, triggers platform ceremony, and calls `CompleteWebAuthnRegistration` | CognitoWebAuthnClient provides all Cognito operations; WebAuthnCredentialPlatform provides createCredential; orchestration follows existing pattern from `setUpTotp` and `deleteUser` |
| AUTH-03 | User can list their registered passkeys via `listWebAuthnCredentials()` returning credential ID, friendly name, relying party ID, authenticator attachment, transports, and creation date | CognitoWebAuthnClient.listWebAuthnCredentials already implemented; pagination follows `fetchDevices` manual loop pattern; AuthWebAuthnCredential model follows AuthDevice/AuthUserAttribute pattern |
| AUTH-04 | User can delete a registered passkey via `deleteWebAuthnCredential(credentialId)` which calls Cognito `DeleteWebAuthnCredential` | CognitoWebAuthnClient.deleteWebAuthnCredential already implemented; void return follows `deleteUser`/`forgetDevice` pattern |
| AUTH-05 | User can check if the current platform supports passkeys via `isPasskeySupported()` returning a boolean | WebAuthnCredentialPlatform.isPasskeySupported already implemented; retrieve via dependency manager `get<T>()` pattern from Phase 2; no network call needed |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| amplify_core | 2.10.1 | Base types, plugin interfaces, category | All Amplify Flutter plugins extend from here |
| amplify_auth_cognito_dart | 0.11.18 | Pure Dart Cognito auth logic | Dual-package pattern — core logic without platform dependencies |
| test | ^1.22.1 | Dart test framework | Standard for all Amplify Flutter unit tests |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| mockito | ^5.0.0 | Mock generation for tests | Testing plugin methods with mock SDK clients |
| amplify_auth_cognito_test | (local) | Shared test utilities | Common matchers, mock clients, storage helpers |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual pagination loop | PaginatedResult<T> | PaginatedResult is for GraphQL API results only; Auth category uses simple List<T> returns (see fetchDevices) |
| fetchAuthSession for token | Direct stateMachine.getUserPoolTokens | getUserPoolTokens is internal pattern used by all authenticated operations; fetchAuthSession is public API |

**Installation:**
No new dependencies required. All components exist in current codebase.

## Architecture Patterns

### Recommended Project Structure
```
packages/
├── amplify_core/lib/src/
│   ├── plugin/amplify_auth_plugin_interface.dart     # Add 4 method stubs
│   ├── category/amplify_auth_category.dart           # Add 4 forwarding methods
│   └── types/auth/credentials/                       # NEW: AuthWebAuthnCredential model
├── auth/amplify_auth_cognito_dart/lib/src/
│   └── auth_plugin_impl.dart                         # Implement 4 orchestration methods
└── auth/amplify_auth_cognito_test/test/plugin/       # Unit tests for each method
```

### Pattern 1: Generic Plugin Interface Stubs
**What:** Add method signatures with `throw UnimplementedError` defaults to `AuthPluginInterface`
**When to use:** Every new Auth category method must start here
**Example:**
```dart
// Source: packages/amplify_core/lib/src/plugin/amplify_auth_plugin_interface.dart
abstract class AuthPluginInterface extends AmplifyPluginInterface {
  /// {@macro amplify_core.amplify_auth_category.associate_webauthn_credential}
  Future<void> associateWebAuthnCredential() {
    throw UnimplementedError('associateWebAuthnCredential() has not been implemented');
  }

  /// {@macro amplify_core.amplify_auth_category.list_webauthn_credentials}
  Future<List<AuthWebAuthnCredential>> listWebAuthnCredentials() {
    throw UnimplementedError('listWebAuthnCredentials() has not been implemented');
  }

  /// {@macro amplify_core.amplify_auth_category.delete_webauthn_credential}
  Future<void> deleteWebAuthnCredential(String credentialId) {
    throw UnimplementedError('deleteWebAuthnCredential() has not been implemented');
  }

  /// {@macro amplify_core.amplify_auth_category.is_passkey_supported}
  Future<bool> isPasskeySupported() {
    throw UnimplementedError('isPasskeySupported() has not been implemented');
  }
}
```

### Pattern 2: Category Delegation
**What:** Forward method calls from `AuthCategory` to `defaultPlugin` using `identifyCall`
**When to use:** Every plugin method needs a corresponding category method
**Example:**
```dart
// Source: packages/amplify_core/lib/src/category/amplify_auth_category.dart (pattern from fetchDevices)
Future<List<AuthDevice>> fetchDevices() => identifyCall(
  AuthCategoryMethod.fetchDevices,
  () => defaultPlugin.fetchDevices(),
);

Future<void> deleteUser() => identifyCall(
  AuthCategoryMethod.deleteUser,
  () => defaultPlugin.deleteUser(),
);
```

### Pattern 3: Access Token Retrieval + Orchestration
**What:** Retrieve access token via `stateMachine.getUserPoolTokens()`, perform operation, propagate errors
**When to use:** All authenticated operations (registration, list, delete)
**Example:**
```dart
// Source: packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart
@override
Future<void> deleteUser() async {
  final tokens = await stateMachine.getUserPoolTokens(); // Throws SignedOutException if not signed in
  await _cognitoIdp
      .deleteUser(
        cognito.DeleteUserRequest(accessToken: tokens.accessToken.raw),
      )
      .result;
  // Clear credentials, emit hub event...
}

@override
Future<List<CognitoDevice>> fetchDevices() async {
  final allDevices = <CognitoDevice>[];
  String? paginationToken;
  do {
    final tokens = await stateMachine.getUserPoolTokens();
    const devicePageLimit = 60;
    final resp = await _cognitoIdp
        .listDevices(
          cognito.ListDevicesRequest(
            accessToken: tokens.accessToken.raw,
            limit: devicePageLimit,
            paginationToken: paginationToken,
          ),
        )
        .result;
    // Accumulate results, update paginationToken...
  } while (paginationToken != null);
  return allDevices;
}
```

### Pattern 4: Platform Bridge Retrieval via Dependency Manager
**What:** Retrieve platform implementation using `stateMachine.get<T>()` with null check
**When to use:** When accessing platform bridges or cross-cutting dependencies
**Example:**
```dart
// Source: Phase 2 implementation (packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart)
final platform = stateMachine.get<WebAuthnCredentialPlatform>();
if (platform == null) {
  throw const PasskeyNotSupportedException('Platform bridge not available');
}
final credentialJson = await platform.createCredential(optionsJson);
```

### Pattern 5: Public Type Definition in amplify_core
**What:** Define shared types in `amplify_core` with immutable data models using `@zAmplifySerializable` or manual JSON
**When to use:** Types that cross plugin boundaries or appear in generic interfaces
**Example:**
```dart
// Source: packages/amplify_core/lib/src/types/auth/auth_device.dart
@immutable
abstract class AuthDevice with AWSSerializable<Map<String, Object?>> {
  const AuthDevice();
  String get id;
  String? get name;
  Map<String, Object?> toJson();
}

// Source: packages/amplify_core/lib/src/types/auth/attribute/auth_user_attribute.dart
@zAmplifySerializable
class AuthUserAttribute
    with AWSEquatable<AuthUserAttribute>, AWSSerializable<Map<String, Object?>>, AWSDebuggable {
  const AuthUserAttribute({
    required this.userAttributeKey,
    required this.value,
  });
  factory AuthUserAttribute.fromJson(Map<String, Object?> json) => _$AuthUserAttributeFromJson(json);
  final AuthUserAttributeKey userAttributeKey;
  final String value;
  // ...
}
```

### Pattern 6: Manual Pagination Loop (Not PaginatedResult)
**What:** Use manual do-while loop accumulating results, not `PaginatedResult<T>` wrapper
**When to use:** Auth category list operations (devices, credentials)
**Why:** `PaginatedResult<T>` is only for GraphQL/API category; Auth category returns simple `List<T>`
**Example:** See fetchDevices in Pattern 3 above

### Anti-Patterns to Avoid
- **Using PaginatedResult for Auth APIs:** `PaginatedResult<T>` is GraphQL-specific. Auth category uses `List<T>` returns with internal pagination loops.
- **Exposing intermediate state:** Don't return registration options or require separate completion calls. Single atomic method is the pattern.
- **Direct fetchAuthSession calls for access token:** Use `stateMachine.getUserPoolTokens()` instead — it's the internal pattern for authenticated operations.
- **Adding options parameters prematurely:** Only add options when SDK requires them (like pagination). Registration takes no options per user decision.
- **Platform-specific code in amplify_core:** Keep pure Dart only. Platform bridges registered by Flutter wrapper via `addPlugin()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Access token management | Custom token refresh logic | `stateMachine.getUserPoolTokens()` | Handles token refresh, device secrets, throws SignedOutException when unauthenticated |
| Pagination accumulation | Custom pagination state | Manual loop pattern from `fetchDevices` | Established pattern, handles nextToken correctly, simple for callers |
| Platform capability checking | Custom platform detection | `WebAuthnCredentialPlatform.isPasskeySupported()` | Already implemented for all 6 platforms (iOS/Android/macOS/Windows/Linux/Web) |
| Cognito WebAuthn API calls | Raw HTTP with auth headers | `CognitoWebAuthnClient` methods | Already handles AWS JSON 1.1 protocol, error mapping, endpoint resolution |
| Error propagation | Custom error wrapping | Direct throw from SDK/platform | Existing layers map to PasskeyException subtypes and Cognito service exceptions |
| Serialization between layers | Custom JSON converters | Existing PasskeyCreateOptions/Result | Phase 1 implementations handle base64url, W3C spec compliance |

**Key insight:** All complex orchestration primitives already exist. This phase is pure API surface design and delegation — no new infrastructure needed.

## Common Pitfalls

### Pitfall 1: Misunderstanding the Pagination Pattern
**What goes wrong:** Trying to return `PaginatedResult<AuthWebAuthnCredential>` because other Amplify APIs use it
**Why it happens:** `PaginatedResult` appears in API/GraphQL categories and looks like the standard
**How to avoid:** Check Auth category precedent — `fetchDevices` returns `List<AuthDevice>`, not paginated result. Manual do-while loop is the pattern.
**Warning signs:** Compiler errors importing `PaginatedResult` into `amplify_core/auth` types; conceptual mismatch when users just want all credentials

### Pitfall 2: Forgetting getUserPoolTokens Throws
**What goes wrong:** Adding explicit `SignedOutException` checks before calling SDK methods
**Why it happens:** User decision says "throw SignedOutException immediately if user is not authenticated"
**How to avoid:** `getUserPoolTokens()` already throws `SignedOutException` when user is signed out — no additional check needed. This is the established pattern in `deleteUser`, `fetchUserAttributes`, etc.
**Warning signs:** Duplicate exception throwing logic; try-catch wrapping `getUserPoolTokens` to rethrow

### Pitfall 3: Platform Bridge in Wrong Package
**What goes wrong:** Trying to call `WebAuthnCredentialPlatform` from Flutter wrapper instead of pure Dart core
**Why it happens:** Assumption that "platform bridge" means "Flutter-only code"
**How to avoid:** The bridge interface is pure Dart (JSON strings boundary). Retrieve via dependency manager in pure Dart package. Flutter wrapper only registers the implementation during `addPlugin()`.
**Warning signs:** Import errors with flutter dependencies in dart package; platform bridge not available in tests

### Pitfall 4: Incomplete Error Handling
**What goes wrong:** Not propagating `PasskeyCancelledException` from platform bridge during registration
**Why it happens:** Focus on success path, forget user can cancel biometric prompt mid-ceremony
**How to avoid:** Platform bridge methods already throw typed exceptions. Let them propagate unchanged — no catch-rethrow needed.
**Warning signs:** Generic `Exception` caught and wrapped in vague error messages; loss of cancellation signal specificity

### Pitfall 5: Race Conditions in Registration Orchestration
**What goes wrong:** Calling CompleteWebAuthnRegistration with wrong session if token refreshes mid-registration
**Why it happens:** Multi-step flow with async operations and token expiry
**How to avoid:** Call `getUserPoolTokens()` once at start of registration, use that token for both Start and Complete. AWS SDK clients handle token expiry at request time.
**Warning signs:** Flaky tests where registration succeeds sometimes; "token mismatch" errors from Cognito

### Pitfall 6: Not Handling ResourceNotFoundException in Delete
**What goes wrong:** Treating delete as idempotent when Cognito throws ResourceNotFoundException
**Why it happens:** Common REST pattern is idempotent deletes
**How to avoid:** User decision explicitly states "throws if credential not found — not idempotent." Let `CognitoWebAuthnClient` error propagate.
**Warning signs:** Swallowing exceptions in delete method; returning success when credential doesn't exist

## Code Examples

Verified patterns from official sources:

### Access Token Retrieval Pattern
```dart
// Source: packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart:625
@override
Future<List<AuthUserAttribute>> fetchUserAttributes({
  FetchUserAttributesOptions? options,
}) async {
  final tokens = await stateMachine.getUserPoolTokens();
  final resp = await _cognitoIdp
      .getUser(cognito.GetUserRequest(accessToken: tokens.accessToken.raw))
      .result;
  return [
    for (final attributeType in resp.userAttributes)
      CognitoUserAttributeKey.fromString(attributeType.name!)
          .toAuthUserAttribute(attributeType.value!),
  ];
}
```

### Manual Pagination Accumulation Pattern
```dart
// Source: packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart:1069
@override
Future<List<CognitoDevice>> fetchDevices() async {
  final allDevices = <CognitoDevice>[];

  String? paginationToken;
  do {
    final tokens = await stateMachine.getUserPoolTokens();
    const devicePageLimit = 60;
    final resp = await _cognitoIdp
        .listDevices(
          cognito.ListDevicesRequest(
            accessToken: tokens.accessToken.raw,
            limit: devicePageLimit,
            paginationToken: paginationToken,
          ),
        )
        .result;

    allDevices.addAll([
      for (final device in resp.devices ?? [])
        CognitoDevice.fromDeviceType(device, tokens.username),
    ]);

    paginationToken = resp.paginationToken;
  } while (paginationToken != null);

  return allDevices;
}
```

### Void Operation with Direct Error Propagation
```dart
// Source: packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart:1145
@override
Future<void> deleteUser() async {
  final tokens = await stateMachine.getUserPoolTokens();
  await _cognitoIdp
      .deleteUser(
        cognito.DeleteUserRequest(accessToken: tokens.accessToken.raw),
      )
      .result;

  // Side effects (clearing storage, hub events) after success
  await signOut();
  await _stateMachine.acceptAndComplete(
    const SignOutEvent(SignOutEventType.deleteUser),
  );
  // ... emit UserDeleted hub event
}
```

### Platform Bridge Retrieval
```dart
// Source: packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart (Phase 2)
Future<AuthenticationResponseJSON> createWebAuthnAssertionRequest({
  required String optionsJson,
}) async {
  final platform = stateMachine.get<WebAuthnCredentialPlatform>();
  if (platform == null) {
    throw const PasskeyNotSupportedException(
      'WebAuthn platform bridge not available',
    );
  }

  final credentialJson = await platform.getCredential(optionsJson);
  return AuthenticationResponseJSON.fromJson(
    jsonDecode(credentialJson) as Map<String, dynamic>,
  );
}
```

### CognitoWebAuthnClient Usage
```dart
// Source: packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart:148
Future<PasskeyCreateOptions> startWebAuthnRegistration({
  required String accessToken,
}) async {
  final responseJson = await _makeRequest(
    target: 'AWSCognitoIdentityProviderService.StartWebAuthnRegistration',
    body: {'AccessToken': accessToken},
  );

  final credentialCreationOptions =
      responseJson['CredentialCreationOptions'] as Map<String, dynamic>;
  return PasskeyCreateOptions.fromJson(credentialCreationOptions);
}
```

### AuthWebAuthnCredential Model Pattern (NEW)
```dart
// Follows pattern from AuthDevice and AuthUserAttribute
@immutable
abstract class AuthWebAuthnCredential
    with AWSSerializable<Map<String, Object?>> {
  const AuthWebAuthnCredential();

  String get credentialId;
  String get relyingPartyId;
  DateTime get createdAt;
  String? get friendlyName;
  String? get authenticatorAttachment;
  List<String>? get authenticatorTransports;

  Map<String, Object?> toJson();
}

// Cognito-specific implementation
class CognitoWebAuthnCredential extends AuthWebAuthnCredential
    with AWSEquatable<CognitoWebAuthnCredential> {
  const CognitoWebAuthnCredential({
    required this.credentialId,
    required this.relyingPartyId,
    required this.createdAt,
    this.friendlyName,
    this.authenticatorAttachment,
    this.authenticatorTransports,
  });

  factory CognitoWebAuthnCredential.fromDescription(
    WebAuthnCredentialDescription description,
  ) {
    return CognitoWebAuthnCredential(
      credentialId: description.credentialId,
      relyingPartyId: description.relyingPartyId,
      createdAt: description.createdAt,
      friendlyName: description.friendlyCredentialName,
      authenticatorAttachment: description.authenticatorAttachment,
      authenticatorTransports: description.authenticatorTransports,
    );
  }

  @override
  final String credentialId;
  @override
  final String relyingPartyId;
  @override
  final DateTime createdAt;
  @override
  final String? friendlyName;
  @override
  final String? authenticatorAttachment;
  @override
  final List<String>? authenticatorTransports;

  @override
  List<Object?> get props => [
    credentialId,
    relyingPartyId,
    createdAt,
    friendlyName,
    authenticatorAttachment,
    authenticatorTransports,
  ];

  @override
  Map<String, Object?> toJson() => {
    'credentialId': credentialId,
    'relyingPartyId': relyingPartyId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (friendlyName != null) 'friendlyName': friendlyName,
    if (authenticatorAttachment != null)
      'authenticatorAttachment': authenticatorAttachment,
    if (authenticatorTransports != null)
      'authenticatorTransports': authenticatorTransports,
  };
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| PaginatedResult for all lists | Manual loops in Auth category, PaginatedResult for GraphQL only | Established pattern since v1.x | Simpler caller API for auth operations, no unnecessary complexity |
| Separate registration start/complete methods | Single atomic orchestration method | Amplify Gen 2 pattern | Better developer experience, fewer failure modes, cleaner error handling |
| fetchAuthSession for tokens in plugin methods | Internal stateMachine.getUserPoolTokens() | Core architecture decision | Cleaner separation, automatic token refresh, consistent error handling |

**Deprecated/outdated:**
- N/A — This is new functionality. No prior passkey APIs exist in Amplify Flutter.

## Open Questions

1. **Should listWebAuthnCredentials support pagination parameters in public API?**
   - What we know: CognitoWebAuthnClient supports maxResults and nextToken. fetchDevices does full pagination internally and returns List<Device>.
   - What's unclear: Whether users will have enough credentials to need pagination control, or if internal full-fetch is sufficient.
   - Recommendation: Follow fetchDevices pattern (internal full pagination, return List<T>). Add pagination parameters later if users request it. YAGNI principle.

2. **What should Cognito-specific result types include?**
   - What we know: Pattern exists for CognitoSignInResult, CognitoDevice with extra fields beyond generic types.
   - What's unclear: What Cognito-specific metadata is useful for developers (e.g., AWS-specific attributes, user pool ID).
   - Recommendation: Start minimal (just inherit generic type). Add Cognito-specific fields in later versions based on user feedback.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Dart test package 1.22.1 |
| Config file | none — see Wave 0 |
| Quick run command | `dart test <specific_test_file>` |
| Full suite command | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-02 | associateWebAuthnCredential orchestrates Start → ceremony → Complete | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart -x` | ❌ Wave 0 |
| AUTH-02 | associateWebAuthnCredential throws SignedOutException when not authenticated | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart::should_throw_signed_out -x` | ❌ Wave 0 |
| AUTH-02 | associateWebAuthnCredential propagates PasskeyCancelledException from platform | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart::should_propagate_cancelled -x` | ❌ Wave 0 |
| AUTH-03 | listWebAuthnCredentials returns all credentials with pagination | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/list_webauthn_credentials_test.dart -x` | ❌ Wave 0 |
| AUTH-03 | listWebAuthnCredentials maps Cognito fields to AuthWebAuthnCredential | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/list_webauthn_credentials_test.dart::should_map_fields -x` | ❌ Wave 0 |
| AUTH-04 | deleteWebAuthnCredential succeeds for valid credential | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/delete_webauthn_credential_test.dart::should_delete -x` | ❌ Wave 0 |
| AUTH-04 | deleteWebAuthnCredential throws ResourceNotFoundException for missing credential | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/delete_webauthn_credential_test.dart::should_throw_not_found -x` | ❌ Wave 0 |
| AUTH-05 | isPasskeySupported returns true when platform available | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/is_passkey_supported_test.dart::should_return_true -x` | ❌ Wave 0 |
| AUTH-05 | isPasskeySupported returns false when platform unavailable | unit | `dart test packages/auth/amplify_auth_cognito_test/test/plugin/is_passkey_supported_test.dart::should_return_false -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `dart test <specific_test_file> -x` (fail fast on first error)
- **Per wave merge:** `dart test packages/auth/amplify_auth_cognito_test/test/plugin/{associate,list,delete,is_passkey}* -x`
- **Phase gate:** All plugin tests green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `packages/auth/amplify_auth_cognito_test/test/plugin/associate_webauthn_credential_test.dart` — covers AUTH-02 (registration orchestration, signed out exception, cancellation propagation)
- [ ] `packages/auth/amplify_auth_cognito_test/test/plugin/list_webauthn_credentials_test.dart` — covers AUTH-03 (pagination, field mapping)
- [ ] `packages/auth/amplify_auth_cognito_test/test/plugin/delete_webauthn_credential_test.dart` — covers AUTH-04 (successful delete, not found exception)
- [ ] `packages/auth/amplify_auth_cognito_test/test/plugin/is_passkey_supported_test.dart` — covers AUTH-05 (platform available/unavailable)
- [ ] `packages/auth/amplify_auth_cognito_test/common/mock_webauthn.dart` — mock WebAuthnCredentialPlatform for tests (follows MockCognitoIdentityProviderClient pattern)

No framework install needed — `test` package already in `amplify_auth_cognito_test/pubspec.yaml` dev_dependencies.

## Sources

### Primary (HIGH confidence)
- Codebase files:
  - `packages/amplify_core/lib/src/plugin/amplify_auth_plugin_interface.dart` - Plugin interface pattern
  - `packages/amplify_core/lib/src/category/amplify_auth_category.dart` - Category delegation pattern
  - `packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart` - Orchestration patterns (fetchDevices, deleteUser, fetchUserAttributes)
  - `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart` - All 4 Cognito operations already implemented
  - `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart` - Platform bridge interface
  - `packages/amplify_core/lib/src/types/auth/auth_device.dart` - Public type pattern for credentials
  - `packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart` - Typed exception hierarchy
- Project files:
  - `.planning/phases/05-credential-management-register-list-delete-apis/05-CONTEXT.md` - User decisions and constraints
  - `.planning/REQUIREMENTS.md` - Phase requirements AUTH-02, AUTH-03, AUTH-04, AUTH-05
  - `.planning/STATE.md` - Project history and accumulated decisions

### Secondary (MEDIUM confidence)
- Codebase test patterns:
  - `packages/auth/amplify_auth_cognito_test/test/plugin/delete_user_test.dart` - Test structure for void authenticated operations
  - `packages/auth/amplify_auth_cognito_test/test/plugin/fetch_current_device_test.dart` - Test structure for retrieve operations

### Tertiary (LOW confidence)
- N/A — All research grounded in existing codebase patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components verified in codebase, no external dependencies
- Architecture: HIGH - Multiple examples of identical patterns for auth operations
- Pitfalls: MEDIUM - Inferred from pattern mismatches, not documented pitfalls
- Validation: HIGH - Test framework and patterns verified in existing test suite

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (30 days - stable domain, established patterns)

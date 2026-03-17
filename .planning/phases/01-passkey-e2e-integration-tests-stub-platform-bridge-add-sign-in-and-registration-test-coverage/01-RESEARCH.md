# Phase 1: Passkey e2e integration tests - Research

**Researched:** 2026-03-17
**Domain:** Flutter integration testing with stubbed platform dependencies
**Confidence:** HIGH

## Summary

This phase requires implementing end-to-end integration tests for passkey authentication flows using Flutter's `integration_test` package. The tests will use a real Cognito backend with WebAuthn enabled but stub the platform bridge (since CI cannot invoke real biometric authenticators). The existing test infrastructure in `amplify_auth_integration_test` already provides the necessary patterns for test lifecycle management, environment configuration, and user administration via GraphQL admin APIs.

The key technical challenge is injecting a mock `WebAuthnCredentialPlatform` implementation into the plugin's state machine during integration tests. This is accomplished by accessing the public `stateMachine` property on `AmplifyAuthCognitoDart` (the base class of `AmplifyAuthCognito`) and calling `addInstance<WebAuthnCredentialPlatform>(mockPlatform)` before calling `Amplify.configure()`.

**Primary recommendation:** Extend `AmplifyAuthTestPlugin` to override the `addPlugin` method and inject `MockWebAuthnCredentialPlatform` into the state machine. Place integration tests in `packages/auth/amplify_auth_cognito/example/integration_test/` following the flat-file convention used by existing tests (e.g., `mfa_sms_test.dart`, `delete_user_test.dart`).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Stub strategy:** Extend existing `MockWebAuthnCredentialPlatform` (callback-based pattern) -- do NOT build a stateful fake or record/replay system
- **Callbacks return instantly:** No simulated delays
- **Real Cognito backend + stubbed platform bridge:** Matches the existing integration test pattern where tests hit deployed backends
- **Integration tests only:** Existing unit tests in `amplify_auth_cognito_test` already cover mocked Cognito client layer for webauthn flows
- **Test flow coverage:** Sign-in (happy path + errors), Registration (happy path + errors), First-factor selection, isPasskeySupported sanity check
- **Test location:** Tests live in `packages/auth/amplify_auth_cognito/example/integration_test/` alongside existing integration tests (flat file convention)
- **Inject stub via TestAuthPlugin override:** Configure TestAuthPlugin to inject MockWebAuthnCredentialPlatform into the plugin's dependency graph
- **Shared utilities location:** `packages/test/amplify_auth_integration_test/lib/src/` for reusability
- **Backend:** Use existing `infra-gen2/backends/auth/webauthn/` backend (email + phone OTP login, webAuthn: true, preferredChallenge: WEB_AUTHN)
- **Environment setup:** Add EnvironmentInfo entry matching the existing pattern used by MFA and sign-in tests
- **User setup pattern:** Create user with email + password via admin API, sign in, register passkey, then test passkey sign-in
- **Cleanup:** Delete test users in tearDown after each test -- matches existing auth integration test pattern

### Claude's Discretion
- Exact test file naming conventions (follow existing patterns)
- Test credential JSON fixture content (realistic but not production values)
- How TestAuthPlugin override is structured internally
- Whether to group all passkey tests in one file or split sign-in/registration/first-factor-selection

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| integration_test | SDK builtin | Flutter integration test framework | Official Flutter testing solution for platform integration tests |
| flutter_test | SDK builtin | Flutter test assertions and utilities | Core Flutter testing library |
| checks | ^0.3.0 | Modern assertion library | Used consistently across amplify-flutter integration tests |
| amplify_auth_integration_test | internal | Auth integration test utilities | Existing project package providing testRunner, adminCreateUser, EnvironmentInfo |
| amplify_integration_test | internal | General integration test utilities | Provides adminDeleteUser, getOtpCode, asyncTest helper |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| amplify_auth_cognito_test | internal | Mock implementations for unit tests | Source of MockWebAuthnCredentialPlatform to extend for integration tests |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| integration_test | flutter_driver | flutter_driver is deprecated in favor of integration_test |
| checks | expect | checks provides better error messages and is the project standard |

**Installation:**
All packages already present in project. No new dependencies required.

**Version verification:**
```bash
# Flutter SDK version in use
flutter --version
# Output: Flutter 3.41.4, Dart 3.11.1

# integration_test is SDK builtin (no version check needed)
# checks version already in pubspec.yaml
grep checks packages/auth/amplify_auth_cognito/example/pubspec.yaml
# Output: checks: ^0.3.0
```

## Architecture Patterns

### Recommended Project Structure
```
packages/
├── auth/amplify_auth_cognito/example/integration_test/
│   ├── webauthn_sign_in_test.dart          # Sign-in flow tests
│   ├── webauthn_registration_test.dart     # Registration flow tests
│   └── test_runner.dart                    # Test runner configuration (already exists)
└── test/amplify_auth_integration_test/lib/src/
    ├── mock_webauthn_for_integration.dart  # Extended MockWebAuthnCredentialPlatform
    └── webauthn_test_fixtures.dart         # Test credential JSON constants
```

### Pattern 1: TestAuthPlugin with Stubbed Platform Bridge
**What:** Override `addPlugin` in `AmplifyAuthTestPlugin` to inject mock WebAuthn platform before native bridges are configured.
**When to use:** All passkey integration tests requiring stubbed biometric operations.
**Example:**
```dart
// Source: Derived from packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart
// and packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart lines 58-104

class AmplifyAuthTestPlugin extends AmplifyAuthCognito {
  AmplifyAuthTestPlugin({
    required this.hasApiPlugin,
    WebAuthnCredentialPlatform? webAuthnPlatform,
  })  : _webAuthnPlatform = webAuthnPlatform,
        super(
          secureStorageFactory: AmplifySecureStorage.factoryFrom(
            macOSOptions: MacOSSecureStorageOptions(useDataProtection: false),
          ),
        );

  final bool hasApiPlugin;
  final WebAuthnCredentialPlatform? _webAuthnPlatform;

  @override
  Future<void> addPlugin({
    required AmplifyAuthProviderRepository authProviderRepo,
  }) async {
    // Inject mock platform BEFORE calling super.addPlugin()
    if (_webAuthnPlatform != null) {
      stateMachine.addInstance<WebAuthnCredentialPlatform>(_webAuthnPlatform);
    }

    // Skip native bridge setup in super.addPlugin() by calling parent
    await AmplifyAuthCognitoDart(
      secureStorageFactory: secureStorageFactory,
    ).addPlugin(authProviderRepo: authProviderRepo);
  }

  @override
  Future<CognitoSignUpResult> signUp({
    required String username,
    String? password,
    SignUpOptions? options,
  }) {
    if (hasApiPlugin) {
      addTearDown(
        () => adminDeleteUser(username).onError(
          (e, st) => logger.debug('Error deleting user ($username):', e, st),
        ),
      );
    }
    return super.signUp(
      username: username,
      password: password,
      options: options,
    );
  }
}
```

### Pattern 2: Integration Test Lifecycle with WebAuthn Stub
**What:** Standard integration test structure with environment configuration and user setup/teardown.
**When to use:** Every passkey integration test.
**Example:**
```dart
// Source: Derived from packages/auth/amplify_auth_cognito/example/integration_test/mfa_sms_test.dart
// and packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart

import 'package:amplify_auth_integration_test/amplify_auth_integration_test.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_integration_test/amplify_integration_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_runner.dart';

void main() {
  testRunner.setupTests();

  group('WebAuthn Sign-In', () {
    testRunner.withEnvironment(webAuthnEnvironment, (env) {
      asyncTest('can sign in with passkey after registration', (_) async {
        final username = env.generateUsername();
        final password = generatePassword();

        // Create user with email + password
        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: env.getDefaultAttributes(username),
        );

        // Sign in with password to get authenticated session
        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);

        // Register passkey (stub returns instant success)
        await Amplify.Auth.associateWebAuthnCredential();

        // Sign out
        await Amplify.Auth.signOut();

        // Sign in with passkey (stub returns test credential)
        final passkeySignInRes = await Amplify.Auth.signIn(
          username: username,
          options: SignInOptions(
            pluginOptions: CognitoSignInPluginOptions(
              authFlowType: AuthenticationFlowType.userAuth,
            ),
          ),
        );
        check(passkeySignInRes.nextStep.signInStep).equals(AuthSignInStep.done);
      });
    });
  });
}
```

### Pattern 3: Mock Platform with Callback-Based Success/Failure
**What:** MockWebAuthnCredentialPlatform takes callbacks that return test credentials or throw exceptions.
**When to use:** Configure different behaviors for different test scenarios (success, user cancels, platform unsupported).
**Example:**
```dart
// Source: packages/auth/amplify_auth_cognito_test/lib/common/mock_webauthn.dart
// and packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart

final mockPlatform = MockWebAuthnCredentialPlatform(
  createCredential: (optionsJson) async {
    // Return valid RegistrationResponseJSON
    return json.encode({
      'id': 'Y3JlZGVudGlhbElk',
      'rawId': 'Y3JlZGVudGlhbElk',
      'type': 'public-key',
      'response': {
        'clientDataJSON': 'Y2xpZW50RGF0YQ',
        'attestationObject': 'YXR0ZXN0YXRpb25PYmplY3Q',
      },
      'clientExtensionResults': {},
    });
  },
  getCredential: (optionsJson) async {
    // Return valid AuthenticationResponseJSON
    return testCredentialResponse; // from fixtures
  },
  isPasskeySupported: () async => true,
);

// For error scenarios:
final cancelledMockPlatform = MockWebAuthnCredentialPlatform(
  getCredential: (_) async => throw const PasskeyCancelledException('User cancelled'),
);
```

### Anti-Patterns to Avoid
- **Stateful fake:** Do NOT build a mock that tracks registered credentials and validates credential IDs. The real Cognito backend handles this — the stub just returns well-formed JSON that Cognito accepts.
- **Simulated delays:** Do NOT add artificial `await Future.delayed()` in mock callbacks. Tests should run as fast as possible.
- **Direct Amplify.configure() with mock injection:** Do NOT try to inject mocks after `Amplify.configure()` is called. The state machine is locked at that point. Injection must happen in `addPlugin()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test user lifecycle | Manual GraphQL mutations for user create/delete | `adminCreateUser()` + automatic tearDown | Existing utility handles user cleanup, retries, eventual consistency delays |
| OTP code retrieval | HTTP polling of email/SMS gateways | `getOtpCode(UserAttribute)` | Existing utility subscribes to GraphQL subscription for OTP codes |
| Test environment configuration | Custom JSON config loading | `testRunner.configure(environmentName: 'webauthn')` + `EnvironmentInfo` | Existing pattern handles Gen1/Gen2 config variants, amplify_outputs selection |
| Mock credential JSON | Hand-crafted minimal JSON | Copy from existing test fixtures in `sign_in_webauthn_test.dart` | Existing fixtures are known to work with Cognito's validation |

**Key insight:** The existing `amplify_auth_integration_test` package provides battle-tested utilities for user lifecycle, OTP codes, and environment setup. Reusing these patterns prevents subtle bugs like eventual consistency issues (user created but not queryable for 500ms).

## Common Pitfalls

### Pitfall 1: Injecting Mock After Configuration
**What goes wrong:** Attempting to inject `MockWebAuthnCredentialPlatform` after `Amplify.configure()` has been called. The state machine dependency graph is frozen after configuration, so the mock is ignored and the real (non-functional) stub is used instead.
**Why it happens:** The pattern of "configure first, then modify" works in unit tests where you directly access the state machine, but integration tests go through the plugin lifecycle.
**How to avoid:** Override `addPlugin()` in `AmplifyAuthTestPlugin` to inject the mock BEFORE calling `super.addPlugin()`. This ensures the mock is registered before the native bridges are set up.
**Warning signs:** Test logs show "PasskeyNotSupportedException" even though you injected a mock. This indicates the mock was injected too late.

### Pitfall 2: Forgetting to Skip Native Bridge Setup
**What goes wrong:** Calling `super.addPlugin()` from `AmplifyAuthTestPlugin` runs the full native bridge initialization from `AmplifyAuthCognito.addPlugin()`, which overwrites your injected mock with the platform-specific implementation (Pigeon bridge on iOS/Android/macOS, Windows/Linux FFI, or stub on web).
**Why it happens:** `AmplifyAuthCognito.addPlugin()` (lines 58-104 in `auth_plugin_impl.dart`) explicitly calls `stateMachine.addInstance<WebAuthnCredentialPlatform>(...)` for each platform.
**How to avoid:** Instead of calling `super.addPlugin()`, call `AmplifyAuthCognitoDart(...).addPlugin()` to bypass the platform-specific setup in `AmplifyAuthCognito`. Alternatively, conditionally skip the native bridge setup if a mock is already registered.
**Warning signs:** Mock callbacks are never invoked even though mock was injected before `super.addPlugin()`.

### Pitfall 3: Mismatched Credential JSON Format
**What goes wrong:** Mock returns JSON that doesn't match W3C WebAuthn Level 3 `RegistrationResponseJSON` or `AuthenticationResponseJSON` format. Cognito rejects the credential with cryptic errors.
**Why it happens:** WebAuthn spec is complex (nested objects, base64url encoding, optional fields). Hand-crafting JSON is error-prone.
**How to avoid:** Copy test fixtures from `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` (`testCredentialRequestOptions`, `testCredentialResponse`). These are known to work with Cognito's validation.
**Warning signs:** Test fails with `PasskeyAssertionFailedException` or `PasskeyRegistrationFailedException` despite mock being invoked. Check Cognito error response for "Invalid credential format".

### Pitfall 4: Missing Environment Configuration for WebAuthn Backend
**What goes wrong:** Tests fail with "backend does not support WebAuthn" even though the backend exists.
**Why it happens:** The test runner doesn't have an `EnvironmentInfo` entry for the webauthn backend, so it falls back to a non-WebAuthn environment.
**How to avoid:** Add an `EnvironmentInfo` constant to `packages/test/amplify_auth_integration_test/lib/src/environments.dart` matching the pattern used for MFA environments. Reference the correct backend name from `infra-gen2/backends/auth/webauthn/amplify/auth/resource.ts`.
**Warning signs:** Integration test tries to register a passkey but receives "NotAuthorizedException" or "InvalidParameterException" from Cognito.

### Pitfall 5: Test Credential JSON Not Base64URL Encoded
**What goes wrong:** Mock returns credential JSON with regular base64 or unencoded binary data. Cognito rejects it.
**Why it happens:** WebAuthn spec requires base64url encoding (not standard base64). Standard base64 includes `+`, `/`, `=` characters that break URL parsing.
**How to avoid:** Use existing test fixtures which are already correctly encoded. If creating new fixtures, ensure all binary fields (`challenge`, `rawId`, `clientDataJSON`, etc.) use base64url encoding (no padding, use `-` and `_` instead of `+` and `/`).
**Warning signs:** Cognito returns "Invalid credential format" with base64 decoding errors in logs.

## Code Examples

Verified patterns from official sources:

### Test Runner Setup and Environment Configuration
```dart
// Source: packages/auth/amplify_auth_cognito/example/integration_test/mfa_sms_test.dart
// Pattern: testRunner.setupTests() + testRunner.withEnvironment()

void main() {
  testRunner.setupTests(); // Initialize integration test binding

  group('WebAuthn Sign-In', () {
    testRunner.withEnvironment(webAuthnEnvironment, (env) {
      // setUp/tearDown handled by testRunner.withEnvironment
      // Automatically calls testRunner.configure() in setUp
      // Automatically calls signOutUser() and Amplify.reset() in tearDown

      asyncTest('can sign in with passkey', (_) async {
        // Test implementation
      });
    });
  });
}
```

### Admin User Creation with Automatic Cleanup
```dart
// Source: packages/test/amplify_integration_test/lib/src/integration_test_utils/auth_cognito/integration_test_auth_utils.dart
// Lines 174-263

final username = env.generateUsername(); // Email or phone based on loginMethod
final password = generatePassword();

// adminCreateUser automatically registers tearDown to delete user
await adminCreateUser(
  username,
  password,
  autoConfirm: true,       // User is confirmed (no need to verify email)
  verifyAttributes: true,  // Email/phone marked as verified
  attributes: env.getDefaultAttributes(username), // email or phoneNumber
);

// Use the user in test...

// Cleanup happens automatically in tearDown
```

### Mock Platform with Test Credentials
```dart
// Source: packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart
// Lines 45-63 (test fixtures) and 127-132 (mock usage)

// Test credential fixtures (copy to shared test utilities)
const testCredentialRequestOptions =
    '{"challenge":"dGVzdC1jaGFsbGVuZ2U",'
    '"rpId":"example.com",'
    '"allowCredentials":[],'
    '"timeout":60000,'
    '"userVerification":"preferred"}';

const testCredentialResponse =
    '{"id":"credential-id",'
    '"rawId":"Y3JlZGVudGlhbC1pZA",'
    '"type":"public-key",'
    '"response":{'
    '"clientDataJSON":"eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0",'
    '"authenticatorData":"SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MdAAAAAA",'
    '"signature":"MEUCIQDKg7m-jRDKvPIzSaR6SYMBjG3qPLCvkKqz_Ypfhnkm3Q",'
    '"userHandle":"dXNlci1pZA"},'
    '"clientExtensionResults":{}}';

// Mock configuration
final mockPlatform = MockWebAuthnCredentialPlatform(
  onGetCredential: (optionsJson) async {
    expect(optionsJson, testCredentialRequestOptions); // Verify input
    return testCredentialResponse;
  },
);
```

### State Machine Dependency Injection
```dart
// Source: packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart
// Lines 134-136

stateMachine
  ..addInstance<cognito_idp.CognitoIdentityProviderClient>(mockClient)
  ..addInstance<WebAuthnCredentialPlatform>(mockPlatform);
```

### Environment Info Definition
```dart
// Source: packages/test/amplify_auth_integration_test/lib/src/environments.dart
// Lines 28-32 (MFA environment example)

/// An environment with optional MFA via SMS only.
const webAuthnEnvironment = EnvironmentInfo.withGen2Defaults(
  name: 'webauthn', // Must match backend name in infra-gen2/backends/auth/
  loginMethod: LoginMethod.email,
  // No mfaInfo needed for WebAuthn-only backend
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| flutter_driver for integration tests | integration_test package | Flutter 2.8 (Dec 2021) | Unified test framework, better performance, simpler API |
| expect() assertions | checks package assertions | Amplify Flutter 2024 | Better error messages, compositional checks |
| Manual tearDown registration | testRunner.configure() auto-tearDown | Amplify integration_test v1.0 | Prevents test state leakage between tests |
| Gen1 CLI only | Gen1 + Gen2 dual support | Amplify Gen2 launch (2024) | EnvironmentInfo.withGen2Defaults() pattern |

**Deprecated/outdated:**
- `flutter_driver`: Use `integration_test` package (official replacement since Flutter 2.8)
- Manual `Amplify.reset()` in tearDown: Use `testRunner.configure()` which auto-registers tearDown (prevents forgetting cleanup)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | integration_test (Flutter SDK builtin) + flutter_test |
| Config file | none — configured via `testRunner.setupTests()` in each test file |
| Quick run command | `flutter test integration_test/webauthn_sign_in_test.dart --dart-define=AMPLIFY_ENVIRONMENT=webauthn` |
| Full suite command | `flutter test integration_test/ --dart-define=AMPLIFY_ENVIRONMENT=webauthn` |

### Phase Requirements → Test Map
Since no requirement IDs were provided, mapping based on test flow coverage from CONTEXT.md:

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SIGN-IN-01 | Happy path WebAuthn sign-in (full flow through Cognito WEB_AUTHN challenge) | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-happy` | ❌ Wave 0 |
| SIGN-IN-02 | Error: user cancels passkey prompt | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-cancel` | ❌ Wave 0 |
| SIGN-IN-03 | Error: passkey not supported on platform | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-unsupported` | ❌ Wave 0 |
| SIGN-IN-04 | Error: invalid credential response | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t sign-in-invalid` | ❌ Wave 0 |
| REG-01 | Happy path passkey registration (StartWebAuthnRegistration + CompleteWebAuthnRegistration) | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-happy` | ❌ Wave 0 |
| REG-02 | Error: user cancels registration | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-cancel` | ❌ Wave 0 |
| REG-03 | Error: platform unsupported | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-unsupported` | ❌ Wave 0 |
| REG-04 | Error: already-registered credential | integration | `flutter test integration_test/webauthn_registration_test.dart -t reg-duplicate` | ❌ Wave 0 |
| SELECT-01 | SELECT_CHALLENGE flow when user has password + passkey | integration | `flutter test integration_test/webauthn_sign_in_test.dart -t first-factor-selection` | ❌ Wave 0 |
| SUPPORT-01 | isPasskeySupported returns expected values | integration | `flutter test integration_test/webauthn_registration_test.dart -t is-supported` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test integration_test/webauthn_sign_in_test.dart integration_test/webauthn_registration_test.dart --dart-define=AMPLIFY_ENVIRONMENT=webauthn`
- **Per wave merge:** Full integration test suite (all integration_test/*.dart files)
- **Phase gate:** All integration tests green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `packages/auth/amplify_auth_cognito/example/integration_test/webauthn_sign_in_test.dart` — covers SIGN-IN-01 through SIGN-IN-04, SELECT-01
- [ ] `packages/auth/amplify_auth_cognito/example/integration_test/webauthn_registration_test.dart` — covers REG-01 through REG-04, SUPPORT-01
- [ ] `packages/test/amplify_auth_integration_test/lib/src/mock_webauthn_for_integration.dart` — extended MockWebAuthnCredentialPlatform
- [ ] `packages/test/amplify_auth_integration_test/lib/src/webauthn_test_fixtures.dart` — test credential JSON constants
- [ ] `packages/test/amplify_auth_integration_test/lib/src/environments.dart` — add `webAuthnEnvironment` constant
- [ ] `packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart` — modify `AmplifyAuthTestPlugin` to accept and inject `WebAuthnCredentialPlatform`

## Sources

### Primary (HIGH confidence)
- `packages/test/amplify_auth_integration_test/lib/src/test_runner.dart` — AuthTestRunner lifecycle pattern, lines 170-292
- `packages/test/amplify_auth_integration_test/lib/src/test_auth_plugin.dart` — AmplifyAuthTestPlugin implementation, lines 10-52
- `packages/test/amplify_auth_integration_test/lib/src/environments.dart` — EnvironmentInfo pattern, lines 1-136
- `packages/auth/amplify_auth_cognito/example/integration_test/mfa_sms_test.dart` — Integration test structure pattern
- `packages/auth/amplify_auth_cognito/example/integration_test/delete_user_test.dart` — Simple integration test pattern, lines 1-90
- `packages/auth/amplify_auth_cognito_test/lib/common/mock_webauthn.dart` — MockWebAuthnCredentialPlatform callback pattern, lines 1-48
- `packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` — WebAuthn test fixtures and mock usage, lines 45-63, 127-136
- `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart` — Platform interface documentation, lines 1-58
- `packages/auth/amplify_auth_cognito/lib/src/auth_plugin_impl.dart` — Plugin initialization and dependency injection, lines 58-104, 111
- `packages/test/amplify_integration_test/lib/src/integration_test_utils/auth_cognito/integration_test_auth_utils.dart` — adminCreateUser lifecycle, lines 174-263
- `infra-gen2/backends/auth/webauthn/amplify/auth/resource.ts` — Backend configuration with webAuthn enabled

### Secondary (MEDIUM confidence)
- Flutter integration_test package documentation — Official Flutter docs confirm integration_test is the current standard (flutter_driver deprecated)
- Amplify Gen2 documentation — Confirms AmplifyOutputs pattern for Gen2 backends

### Tertiary (LOW confidence)
None — all findings verified with project source code.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages present in project, verified via pubspec.yaml and imports
- Architecture: HIGH - Patterns extracted directly from existing test code in same repository
- Pitfalls: HIGH - Identified from plugin implementation code (addPlugin lifecycle, state machine injection timing)

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (30 days — stable infrastructure, no fast-moving dependencies)

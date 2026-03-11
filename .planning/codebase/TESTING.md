# Testing Patterns

**Analysis Date:** 2026-03-07

## Test Framework

**Runner:**
- `package:test` ^1.22.1 -- for pure Dart packages
- `package:flutter_test` -- for Flutter packages (widget tests)
- `package:integration_test` -- for Flutter integration/E2E tests
- Config: `dart_test.yaml` (per-package, not all packages have one)

**Assertion Library:**
- Built-in `package:test` matchers (`expect`, `throwsA`, `isA`, `completion`)
- Custom matchers defined in test packages (e.g., `throwsSignedOutException`)

**Mocking Library:**
- `package:mocktail` (preferred) -- used in storage, analytics, authenticator, api packages
- Hand-written mocks (used in auth) -- constructor-injected callback-based mocks
- No `package:mockito` usage detected

**Run Commands:**
```bash
# Run all unit tests for a Dart package
dart test

# Run all unit tests for a Flutter package
flutter test

# Run with coverage
flutter test --coverage

# Run via aft (repo-wide)
aft run test:unit:flutter

# Run specific test file
dart test test/path/to_test.dart

# Run Flutter integration tests
flutter test integration_test/

# Run tests on specific platform
dart test -p chrome
dart test -p firefox
dart test -p vm
```

## Test File Organization

**Location:**
- Unit tests: `<package>/test/` directory, mirroring `lib/src/` structure
- Integration tests: `<package>/example/integration_test/` directory
- Test driver: `<package>/example/test_driver/integration_test.dart`

**Naming:**
- Test files: `<feature>_test.dart` (e.g., `sign_in_test.dart`, `storage_s3_service_test.dart`)
- Mock files: `mock_<thing>.dart` (e.g., `mock_clients.dart`, `mock_secure_storage.dart`)
- Test utility files: `test_<thing>.dart` (e.g., `test_path_resolver.dart`, `test_token_provider.dart`)
- Mocks directory: `test/test_utils/mocks.dart` or `lib/common/mock_*.dart` (for shared test packages)

**Structure:**
```
packages/storage/amplify_storage_s3_dart/
├── lib/src/
│   ├── storage_s3_service/
│   └── path_resolver/
├── test/
│   ├── amplify_storage_s3_dart_test.dart     # Top-level plugin tests
│   ├── test_utils/
│   │   ├── mocks.dart                         # Mock classes
│   │   ├── test_path_resolver.dart
│   │   └── test_token_provider.dart
│   ├── storage_s3_service/
│   │   ├── storage_s3_service_test.dart
│   │   └── task/
│   │       ├── s3_download_task_test.dart
│   │       └── s3_upload_task_test.dart
│   ├── path_resolver/
│   │   └── path_resolver_test.dart
│   └── ensure_build_test.dart                 # Generated code freshness check
```

## Shared Test Packages

The repo has dedicated test utility packages under `packages/test/`:

**`packages/test/amplify_test`:**
- Common utilities for all Amplify packages
- Exports: `src/json.dart`, `src/mock_data.dart`
- Cannot reference published packages (avoids circular deps during publishing)
- Pubspec: depends only on `amplify_core` and `aws_common`

**`packages/test/amplify_integration_test`:**
- Utilities for integration tests
- Contains SDK stubs, integration test helpers
- Location: `packages/test/amplify_integration_test/lib/src/`

**`packages/test/amplify_auth_integration_test`:**
- Auth-specific integration test utilities
- Provides `asyncTest()` helper for integration tests

**Category-specific test packages:**
- `packages/auth/amplify_auth_cognito_test/` -- auth mocks, fixtures, shared test code
- `packages/authenticator/amplify_authenticator_test/` -- UI test helpers, page objects
- `packages/secure_storage/amplify_secure_storage_test/` -- storage test utilities

## Test Structure

**Suite Organization:**
```dart
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:test/test.dart';  // or package:flutter_test/flutter_test.dart

void main() {
  group('ClassName', () {
    late SomeService service;
    late MockDependency mockDep;

    setUp(() {
      mockDep = MockDependency();
      service = SomeService(dependency: mockDep);
    });

    tearDown(() {
      service.close();
    });

    group('methodName()', () {
      test('should do expected behavior', () async {
        // Arrange
        when(() => mockDep.action()).thenReturn(value);

        // Act
        final result = await service.methodName();

        // Assert
        expect(result, expectedValue);
      });

      test('should throw on invalid input', () async {
        await expectLater(
          service.methodName(),
          throwsA(isA<SpecificException>()),
        );
      });
    });
  });
}
```

**Patterns:**
- `setUp()` / `tearDown()` per group for state isolation
- `setUpAll()` for expensive one-time setup (e.g., `registerFallbackValue`)
- `Amplify.reset()` in `tearDown` for tests that configure Amplify
- Nested `group()` calls: outer = class, inner = method/feature

## Mocking

**Mocktail Pattern (preferred for new code):**
```dart
import 'package:mocktail/mocktail.dart';

class MockStorageS3Service extends Mock implements StorageS3Service {}
class MockS3Client extends Mock implements S3Client {}
class MockAWSLogger extends Mock implements AWSLogger {
  @override
  String get runtimeTypeName => 'MockAWSLogger';
}
```

Location: `test/test_utils/mocks.dart`

**Hand-written Mock Pattern (auth packages):**
```dart
class MockCognitoIdentityProviderClient
    implements CognitoIdentityProviderClient {
  MockCognitoIdentityProviderClient({
    Future<InitiateAuthResponse> Function(InitiateAuthRequest)? initiateAuth,
    Future<GlobalSignOutResponse> Function()? globalSignOut,
    // ... other method callbacks
  }) : _initiateAuth = initiateAuth,
       _globalSignOut = globalSignOut;

  final Future<InitiateAuthResponse> Function(InitiateAuthRequest)? _initiateAuth;

  @override
  SmithyOperation<InitiateAuthResponse> initiateAuth(
    InitiateAuthRequest input, {
    AWSHttpClient? client,
    AWSCredentialsProvider? credentialsProvider,
  }) => _mockIfProvided(
    _initiateAuth == null ? null : () => _initiateAuth(input),
  );
}
```

Location: `packages/auth/amplify_auth_cognito_test/lib/common/mock_clients.dart`

**In-memory Storage Mock:**
```dart
class MockSecureStorage implements SecureStorageInterface {
  final Map<String, String> _storage = {};

  @override
  void delete({required String key}) => _storage.remove(key);
  @override
  String? read({required String key}) => _storage[key];
  @override
  void write({required String key, required String value}) =>
      _storage[key] = value;
}
```

Location: `packages/auth/amplify_auth_cognito_test/lib/common/mock_secure_storage.dart`

**What to Mock:**
- External service clients (S3, Cognito IDP, Cognito Identity)
- Storage backends (`SecureStorageInterface`)
- HTTP clients (`AWSHttpClient`)
- Loggers (`AWSLogger`)

**What NOT to Mock:**
- Configuration objects (use real `AmplifyConfig` / `AmplifyOutputs`)
- Exception classes
- State machine events and states
- Value objects and data models

## Test Dependency Injection

The codebase uses `DependencyManager` for injecting test doubles:

```dart
// In production code -- accept optional override
class AmplifyStorageS3Dart extends StoragePluginInterface {
  AmplifyStorageS3Dart({
    @visibleForTesting DependencyManager? dependencyManagerOverride,
  }) : _dependencyManagerOverride = dependencyManagerOverride;
}

// In tests
setUp(() async {
  dependencyManager = AmplifyDependencyManager();
  storageS3Service = MockStorageS3Service();
  storageS3Plugin = AmplifyStorageS3Dart(
    dependencyManagerOverride: dependencyManager,
  );
  dependencyManager.addInstance<StorageS3Service>(storageS3Service);
});
```

For state machine tests, inject mocks via `stateMachine.addInstance<T>()`:
```dart
stateMachine.addInstance<CognitoIdentityProviderClient>(mockIdp);
```

## Fixtures and Factories

**Mock Config Data:**
```dart
// packages/auth/amplify_auth_cognito_test/lib/common/mock_config.dart
const amplifyConfig = '''{
  "version": "1",
  "auth": {
    "aws_region": "region",
    "user_pool_id": "us-east-1_userPoolId",
    "user_pool_client_id": "appClientId",
    ...
  }
}''';
```

**Test Data Constants:**
- JWT tokens, usernames, device keys defined as constants in mock_config files
- Use `const` where possible for test fixtures

**Page Objects (UI tests):**
```dart
// packages/authenticator/amplify_authenticator_test/lib/src/pages/
final signInPage = SignInPage(tester: tester);
await signInPage.enterUsername(testUser.email!);
await signInPage.enterPassword(testUser.password!);
await signInPage.submitSignIn();
```

**Stub Plugin (UI tests):**
```dart
// For widget tests that need a functioning auth layer without real AWS
AmplifyAuthCognitoStub(users: [testUser])
```

Location: `packages/test/amplify_integration_test/`

## Coverage

**Requirements:** No enforced minimum coverage target
**Collection:** `flutter test --coverage` produces `lcov.info`
**CI:** Coverage is collected during `test:unit:flutter` script via `--coverage` flag

## Test Types

**Unit Tests:**
- Located in `<package>/test/`
- Run with `dart test` or `flutter test`
- Mock all external dependencies
- Test individual classes/functions in isolation
- ~373 test files across the repo (excluding goldens)

**Ensure Build Tests:**
- Special test that verifies generated code (`.g.dart` files) is up to date
- Uses `package:build_verify`
- Pattern:
```dart
@TestOn('vm')
@Tags(['build'])
library;

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Ensure Build',
    () => expectBuildClean(
      packageRelativeDirectory: 'packages/auth/amplify_auth_cognito_dart',
    ),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
```

Location: `test/ensure_build_test.dart` in packages with code generation

**Integration Tests:**
- Located in `<package>/example/integration_test/`
- Require provisioned AWS backend resources
- Use `asyncTest()` helper for proper async handling:
```dart
asyncTest('should signIn a user', (_) async {
  final res = await Amplify.Auth.signIn(
    username: username,
    password: password,
  );
  expect(res.isSignedIn, true);
});
```
- `asyncTest` wraps `testWidgets` with a `FutureGroup` for managing async expectations

**Widget Tests (Authenticator):**
- Use `MockAuthenticatorApp` widget that wires up `AmplifyStub` + `AmplifyAuthCognitoStub`
- Page object pattern: `SignInPage`, `SignUpPage` etc.
- `tester.pumpWidget()` + `tester.pumpAndSettle()` pattern

**Platform Tests:**
- Native iOS: XCTest via `xcodebuild test` (see `tool/test_all_plugins.sh`)
- Native Android: Gradle `testDebugUnitTest`
- Browser: `dart test -p chrome` / `dart test -p firefox`
- Platform-specific test files: `*_io_test.dart`, `*_html_test.dart`

**Golden Tests (Smithy):**
- Protocol conformance tests in `packages/smithy/goldens/`
- Generated from Smithy model definitions
- Verify serialization/deserialization of AWS protocol formats

## Test Configuration

**`dart_test.yaml` settings (when present):**
```yaml
override_platforms:
  firefox:
    settings:
      arguments: -headless
on_platform:
  browser:
    timeout: 2x
```

**Test Annotations:**
- `@TestOn('vm')` -- restrict to VM only (no browser)
- `@TestOn('windows || mac-os || linux')` -- desktop platforms only
- `@Tags(['build'])` -- tag for filtering

## CI/CD Test Pipeline

**Workflows** are auto-generated via `aft generate workflows`:
- Per-package workflows: `.github/workflows/amplify_core.yaml`, etc.
- Triggered on push to `main`/`stable` and PRs touching relevant paths
- Multi-platform matrix: VM, DDC (dev compiler), dart2js
- Schedule: weekly runs (Monday 06:00 PST)

**Test Runner Script:** `tool/test_all_plugins.sh`
- Accepts `flutter`, `android`, or `ios` as first argument
- Produces JUnit XML reports in `test-results/`
- Uses `junitreport` for Flutter test output conversion

## Common Patterns

**Async Testing:**
```dart
test('async operation succeeds', () async {
  await expectLater(
    plugin.signIn(username: username, password: 'password'),
    completion(
      isA<CognitoSignInResult>().having(
        (res) => res.isSignedIn,
        'isSignedIn',
        isTrue,
      ),
    ),
  );
});
```

**Error Testing:**
```dart
test('throws on invalid state', () async {
  await expectLater(
    plugin.signIn(username: username, password: 'password'),
    throwsA(isA<InvalidStateException>()),
    reason: 'Calling signIn while authenticated should fail',
  );
});
```

**Mocktail Verification:**
```dart
final capturedOptions = verify(
  () => storageS3Service.list(
    path: testPath,
    options: captureAny<StorageListOptions>(named: 'options'),
  ),
).captured.last;

expect(capturedOptions, defaultOptions);
```

**Zone-based Test Configuration:**
```dart
// Use Zone values for test-only behavior
bool get _zIsTest => Zone.current[zIsTest] as bool? ?? false;
```

**State Machine Testing:**
```dart
final signInStateMachine = stateMachine.expect(SignInStateMachine.type);

stateMachine.dispatch(
  SignInEvent.initiate(
    authFlowType: AuthenticationFlowType.customAuthWithSrp,
    parameters: SignInParameters(...),
  ),
).ignore();

await expectLater(
  stateMachine.stream.whereType<ConfigurationState>().firstWhere(
    (event) => event is Configured || event is ConfigureFailure,
  ),
  completion(isA<Configured>()),
);
```

**Integration Test User Management:**
```dart
setUp(() async {
  await testRunner.configure(environmentName: environment.name);
  username = environment.generateUsername();
  password = generatePassword();
  await adminCreateUser(username, password, autoConfirm: true);
  await signOutUser();
});
```

---

*Testing analysis: 2026-03-07*

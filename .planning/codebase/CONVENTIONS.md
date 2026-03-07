# Coding Conventions

**Analysis Date:** 2026-03-07

## License Headers

Every Dart file MUST begin with the Amazon copyright and SPDX license header:

```dart
// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
```

This is enforced by `tool/license.sh` and checked in CI.

## Naming Patterns

**Files:**
- Use `snake_case` for all Dart files: `amplify_storage_s3_dart_impl.dart`, `mock_secure_storage.dart`
- Platform-specific files use suffixes: `.vm.dart`, `.js.dart`, `.html.dart`, `.io.dart`
- Generated files use `.g.dart` suffix (e.g., `native_auth_plugin.g.dart`)
- Worker-specific platform files: `.worker.vm.dart`, `.worker.js.dart`
- Test files: `*_test.dart` suffix (never `.test.dart`)

**Packages:**
- Dart-only packages: `amplify_<category>_<service>_dart` (e.g., `amplify_auth_cognito_dart`)
- Flutter packages: `amplify_<category>_<service>` (e.g., `amplify_auth_cognito`)
- Test packages: `amplify_<category>_<service>_test` (e.g., `amplify_auth_cognito_test`)
- Shared/common: `aws_common`, `amplify_core`

**Classes:**
- Use PascalCase: `AmplifyStorageS3Dart`, `CognitoAuthStateMachine`
- Prefix with `Amplify` or `AWS` for public API classes
- Prefix with `Mock` for test mocks: `MockSecureStorage`, `MockCognitoIdentityProviderClient`
- Prefix with `_` for private implementations: `_AmplifyException`
- Use `sealed` for category exception hierarchies: `sealed class StorageException extends AmplifyException`
- Use `abstract interface class` for interfaces: `abstract interface class PreconditionException`

**Functions/Methods:**
- Use camelCase: `signIn`, `fetchAuthSession`, `abortIncompleteMultipartUploads`
- Factory constructors: `AmplifyException.fromMap()`, `AuthException.fromException()`
- Named constructors: `AWSLogger.detached()`, `AWSLogger.protected()`

**Variables:**
- Use camelCase for variables and parameters
- Use `prefer_final_locals` (enforced by linter) -- always use `final` for local variables that are not reassigned
- Use `prefer_final_in_for_each` (enforced by linter)
- Prefix test-only constants with `z`: `zIsTest`, `zDefaultLogLevel`

**Types:**
- Use `const` constructors wherever possible (enforced by `prefer_const_constructors`)
- Generic type parameters follow Dart convention: `T`, `E`, `S`, `Manager`, `M`

## Code Style

**Formatting:**
- `dart format` (standard Dart formatter)
- No custom line length (80 chars guideline noted but not enforced as lint)
- Run via: `aft format --set-exit-if-changed .`

**Linting:**
- Custom lint package: `packages/amplify_lints`
  - `package:amplify_lints/library.yaml` -- for published packages (stricter, requires `public_member_api_docs`)
  - `package:amplify_lints/app.yaml` -- for example apps and internal tools (relaxed, no public docs requirement)
- Base: `package:lints/recommended.yaml` (library) / `package:flutter_lints/flutter.yaml` (app)
- Strict mode enabled for all packages:
  - `strict-casts: true`
  - `strict-inference: true`
  - `strict-raw-types: true`

**Key Lint Rules (enforced):**
- `always_use_package_imports` -- never use relative imports
- `prefer_single_quotes` -- use single quotes for strings
- `only_throw_errors` -- only throw `Exception` subclasses, never arbitrary objects
- `avoid_catches_without_on_clauses` -- always specify exception type in catch
- `avoid_print` -- use `AmplifyLogger`/`AWSLogger` or `safePrint` instead
- `flutter_style_todos` -- TODOs must reference a GitHub issue: `// TODO(username): description`
- `unawaited_futures` -- explicitly mark fire-and-forget futures
- `sort_constructors_first` -- constructors before methods in class body
- `sort_pub_dependencies` -- alphabetical deps in pubspec.yaml
- `public_member_api_docs` -- all public APIs must have dartdoc (library packages only)
- `eol_at_end_of_file` -- newline at end of file

**Generated Code Exclusions:**
- `lib/**/*.g.dart` files are excluded from analysis (configured in each package's `analysis_options.yaml`)

## Import Organization

**Order** (enforced by `directives_ordering` lint):
1. `dart:` SDK imports
2. `package:` imports (external packages)
3. Relative imports (avoided -- use `always_use_package_imports`)

**Path Aliases:**
- No path aliases used; all imports are `package:` imports
- Internal/private imports use `package:package_name/src/...` with `// ignore: implementation_imports` when necessary

**Conditional Imports (platform-specific code):**
```dart
export 'src/utils.vm.dart'
    if (dart.library.js_interop) 'src/utils.js.dart';
```

**Barrel Files:**
- Each package has a top-level barrel file: `lib/<package_name>.dart`
- Barrel files use explicit `export` statements, not `export 'src/';`
- Use `show`/`hide` to control public API surface
- Example: `packages/amplify_core/lib/amplify_core.dart`

## Error Handling

**Exception Hierarchy:**
- Base: `AmplifyException` (abstract, in `packages/amplify_core/lib/src/types/exception/amplify_exception.dart`)
- Category sealed classes: `AuthException`, `StorageException`, `ApiException`, `AnalyticsException`
- Specific exceptions: `AuthNotAuthorizedException`, `StorageNotFoundException`, etc.
- All exceptions include: `message`, optional `recoverySuggestion`, optional `underlyingException`
- All exceptions mix in `AWSDebuggable`, `AWSEquatable`, `AWSSerializable`

**Pattern for creating category exceptions:**
```dart
sealed class StorageException extends AmplifyException with AWSDebuggable {
  const StorageException(super.message, {super.recoverySuggestion, super.underlyingException});
}

class StorageNotFoundException extends StorageException {
  const StorageNotFoundException(super.message, {super.recoverySuggestion, super.underlyingException});
}
```

**Pattern for handling exceptions:**
```dart
static AuthException fromException(Exception e) {
  if (e is AuthException) return e;
  if (e is AmplifyException) {
    return UnknownException(e.message, ...);
  }
  if (e is AWSHttpException) return e.toNetworkException();
  return UnknownException(message, underlyingException: e);
}
```

**Configuration Errors:**
- Throw `ConfigurationError` (not a generic exception) for invalid config

## Logging

**Framework:** Custom `AWSLogger` / `AmplifyLogger` hierarchy built on `package:logging`

**Usage Pattern:**
- Mix in `AWSLoggerMixin` or `AmplifyLoggerMixin` on classes that extend `AWSDebuggable`
- Logger automatically uses `runtimeTypeName` as namespace
- `packages/aws_common/lib/src/logging/aws_logger.dart` -- base logger
- `packages/amplify_core/lib/src/logger/amplify_logger.dart` -- Amplify-specific logger

```dart
class MyPlugin extends StoragePluginInterface
    with AWSDebuggable, AWSLoggerMixin {
  @override
  String get runtimeTypeName => 'MyPlugin';

  void doWork() {
    logger.info('Doing work');
  }
}
```

**Do NOT use `print()`** -- use `safePrint()` from `package:amplify_core` for user-facing output, or `logger` for debug output.

## Comments

**Documentation:**
- All public APIs in library packages MUST have dartdoc comments (enforced by `public_member_api_docs`)
- Use `{@template}` / `{@macro}` for reusable documentation blocks
- Use `{@category}` for organizing in generated docs
- Use `/// @nodoc` to hide internal APIs from generated docs

```dart
/// {@template amplify_core.amplify_exception}
/// Thrown from top level Amplify APIs.
/// {@endtemplate}
abstract class AmplifyException { ... }

/// {@macro amplify_core.amplify_exception}
class ConcreteException extends AmplifyException { ... }
```

**TODOs:**
- Must follow flutter-style format: `// TODO(username): description`
- Reference GitHub issues when possible

## Function Design

**Parameters:**
- Avoid positional boolean parameters (enforced by `avoid_positional_boolean_parameters`)
- Use named parameters for optional arguments
- Use `@visibleForTesting` for test-only parameters (e.g., `DependencyManager? dependencyManagerOverride`)
- Use `@protected` for subclass-only APIs
- Use `@internal` for repo-internal APIs not intended for external consumers

**Return Values:**
- Avoid `void` async functions (enforced by `avoid_void_async`) -- return `Future<void>` instead
- Use `@useResult` for methods whose return values should not be discarded

## Module Design

**Exports:**
- Each package has a single public barrel file
- Internal/private code lives under `lib/src/`
- Use `part`/`part of` sparingly (mainly for exception hierarchies)
- Library declarations use `library;` (unnamed) form

**Package Structure (Dart-first pattern):**
- Pure-Dart package: `amplify_<x>_dart` -- contains core logic, works on all Dart platforms
- Flutter package: `amplify_<x>` -- wraps Dart package with Flutter-specific platform channels
- Test package: `amplify_<x>_test` -- shared test utilities, mocks, and fixtures

**Visibility Annotations:**
- `@visibleForTesting` -- accessible but only for test use
- `@internal` -- accessible within the repo but not part of public API
- `@protected` -- subclass-only access
- `@mustCallSuper` -- subclass overrides must call super

## State Machine Pattern

Core business logic uses a state machine architecture (`packages/amplify_core/lib/src/state_machine/`):
- Events (`StateMachineEvent`) trigger transitions
- States (`StateMachineState`) represent current status
- `StateMachineManager` acts as dispatcher and dependency manager
- `StateMachineToken` used for type-safe service location
- Pattern used extensively in Auth package: `CognitoAuthStateMachine`, `SignInStateMachine`

## Dependency Injection

**`DependencyManager`** pattern (not a third-party DI framework):
- `addInstance<T>()` to register a dependency
- `expect<T>()` to retrieve (throws if missing)
- `getOrCreate<T>()` to lazily create
- `DependencyManager.scoped()` for plugin-scoped dependencies
- Use `dependencyManagerOverride` constructor parameter for test injection

---

*Convention analysis: 2026-03-07*

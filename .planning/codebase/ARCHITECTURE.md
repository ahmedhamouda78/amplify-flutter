# Architecture

**Analysis Date:** 2026-03-07

## Pattern Overview

**Overall:** Plugin-based monorepo with category abstraction pattern

**Key Characteristics:**
- Singleton `Amplify` object acts as the central entry point for all categories
- Plugin architecture where each AWS service (Cognito, S3, Pinpoint, etc.) registers as a plugin into a category
- Dual-package pattern: each category has a pure Dart (`_dart`) package and a Flutter-specific wrapper package
- State machine framework for complex async flows (auth, credential management)
- Pigeon-based native interop for iOS/Android platform channels
- Smithy code generation for AWS SDK clients
- Topological dependency resolution for plugin configuration ordering

## Layers

**Core Layer (`amplify_core`):**
- Purpose: Defines all abstractions, interfaces, types, and base classes shared across the entire framework
- Location: `packages/amplify_core/lib/`
- Contains: `AmplifyClass` singleton, category base classes, plugin interfaces, state machine framework, config parsing, exception hierarchy, type definitions
- Depends on: `aws_common`, `aws_signature_v4`
- Used by: Every other package in the repo

**AWS Common Layer (`aws_common`, `aws_signature_v4`):**
- Purpose: Low-level AWS primitives: HTTP client, credentials, SigV4 signing, logging, serialization
- Location: `packages/aws_common/lib/`, `packages/aws_signature_v4/lib/`
- Contains: `AWSHttpClient`, `AWSHttpRequest`, `AWSHttpResponse`, `AWSCredentials`, `AWSSigV4Signer`, logging framework
- Depends on: Nothing (foundational)
- Used by: `amplify_core`, all category implementations

**Category Interface Layer (within `amplify_core`):**
- Purpose: Defines the public API contract for each Amplify category
- Location: `packages/amplify_core/lib/src/category/`, `packages/amplify_core/lib/src/plugin/`
- Contains: `AuthCategory`, `StorageCategory`, `APICategory`, `AnalyticsCategory`, `DataStoreCategory`, `NotificationsCategory` and their corresponding `*PluginInterface` abstract classes
- Depends on: Core types and exceptions
- Used by: Plugin implementations and end-user code

**Dart Plugin Implementation Layer:**
- Purpose: Pure Dart implementations of each category plugin (platform-independent)
- Location:
  - `packages/auth/amplify_auth_cognito_dart/lib/src/`
  - `packages/storage/amplify_storage_s3_dart/lib/src/`
  - `packages/api/amplify_api_dart/lib/src/`
  - `packages/analytics/amplify_analytics_pinpoint_dart/lib/src/`
- Contains: Full business logic, state machines, SDK clients, credential management
- Depends on: `amplify_core`, `aws_common`, generated Smithy SDK clients
- Used by: Flutter plugin wrappers, pure Dart applications

**Flutter Plugin Wrapper Layer:**
- Purpose: Adds Flutter-specific functionality (platform channels, native interop, secure storage)
- Location:
  - `packages/auth/amplify_auth_cognito/lib/src/`
  - `packages/storage/amplify_storage_s3/lib/src/`
  - `packages/api/amplify_api/lib/src/`
  - `packages/analytics/amplify_analytics_pinpoint/lib/src/`
- Contains: Thin wrappers extending Dart plugins with native platform support via Pigeon
- Depends on: Corresponding `_dart` package, Flutter SDK, Pigeon-generated bindings
- Used by: Flutter applications via `amplify_flutter`

**Top-Level Entry Point (`amplify_flutter`):**
- Purpose: Re-exports `amplify_core` and provides the Flutter-specific `Amplify` singleton
- Location: `packages/amplify/amplify_flutter/lib/`
- Contains: `AmplifyClassImpl` (factory choosing Dart-only or hybrid implementation based on platform)
- Depends on: `amplify_core`, `amplify_secure_storage`
- Used by: End-user Flutter applications

**Smithy SDK Layer:**
- Purpose: Code generation and runtime for AWS service clients
- Location: `packages/smithy/`
- Contains: Smithy model parser, Dart code generator, runtime serialization/deserialization, HTTP protocol support
- Depends on: `aws_common`
- Used by: Category Dart plugins for AWS API calls (Cognito, S3, Pinpoint, etc.)

**UI Layer (`amplify_authenticator`):**
- Purpose: Pre-built Flutter UI components for authentication flows
- Location: `packages/authenticator/amplify_authenticator/lib/src/`
- Contains: BLoCs, screens, widgets, state management, l10n
- Depends on: `amplify_flutter`, `amplify_auth_cognito`
- Used by: Flutter applications wanting drop-in auth UI

**Infrastructure/Utility Packages:**
- `packages/secure_storage/` - Secure key-value storage (Dart + Flutter)
- `packages/common/amplify_db_common*/` - Database utilities (Drift-based)
- `packages/worker_bee/` - Web Worker / Isolate abstraction
- `packages/amplify_foundation/` - Foundation layer with credentials, logging, result types

## Data Flow

**Plugin Registration and Configuration:**

1. User calls `Amplify.addPlugin(AmplifyAuthCognito())` which routes through `AmplifyClass.addPlugin()` → `addPluginPlatform()` → `AuthCategory.addPlugin()`
2. User calls `Amplify.configure(jsonString)` which parses JSON into `AmplifyOutputs` (Gen 2) or `AmplifyConfig` (Gen 1, converted)
3. Categories are topologically sorted by `categoryDependencies` using the `graphs` package
4. Each plugin's `configure()` method is called with the parsed config and shared `AmplifyAuthProviderRepository`

**Auth Flow (State Machine):**

1. User calls `Amplify.Auth.signIn(username, password)` → delegates to `AmplifyAuthCognitoDart.signIn()`
2. Plugin dispatches a `SignInEvent` to the `CognitoStateMachine` manager
3. `CognitoStateMachine.mapEventToMachine()` routes to `SignInStateMachine`
4. `SignInStateMachine.resolve()` processes the event, calls Cognito SDK via Smithy-generated client
5. State transitions emit through `StateMachine.emit()` → broadcast to manager's unified stream
6. Plugin awaits completion via `EventCompleter.completed` and returns result to user

**API Request Flow:**

1. User calls `Amplify.API.query(request: graphQLRequest)` → delegates to `AmplifyAPIDart`
2. Plugin resolves auth mode, selects HTTP client from pool, applies authorization headers
3. For subscriptions: WebSocket BLoC manages connection lifecycle and reconnection
4. Response deserialized and returned as `GraphQLResponse`

**State Management:**
- `StateMachineManager` acts as the central dispatcher for a system of related state machines
- Events flow through a single `StreamController` queue, processed sequentially per machine
- Each `StateMachine` has `initialState`, `resolve(event)`, and `resolveError()` methods
- `DependencyManager` (service locator pattern) provides IoC for state machines and plugins

## Key Abstractions

**AmplifyClass (Singleton):**
- Purpose: Central Amplify entry point providing access to all categories
- Examples: `packages/amplify_core/lib/src/amplify_class.dart`, `packages/amplify/amplify_flutter/lib/src/amplify_impl.dart`
- Pattern: Singleton with replaceable instance. `AmplifyClassImpl` (core, Dart-only) vs `AmplifyHybridImpl` (Flutter, platform channels)

**AmplifyCategory<P>:**
- Purpose: Base class for all Amplify categories, manages plugin registration
- Examples: `packages/amplify_core/lib/src/category/amplify_categories.dart`
- Pattern: Generic over plugin type `P extends AmplifyPluginInterface`. Holds list of plugins, delegates to `defaultPlugin`

**AmplifyPluginInterface:**
- Purpose: Base class for all plugins implementing a category
- Examples: `packages/amplify_core/lib/src/plugin/amplify_plugin_interface.dart`
- Pattern: Defines `category`, `addPlugin()`, `configure()`, `reset()` lifecycle. Scoped `DependencyManager` per plugin

**StateMachine / StateMachineManager:**
- Purpose: Event-driven state machine framework for complex async workflows
- Examples: `packages/amplify_core/lib/src/state_machine/state_machine.dart`, `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/`
- Pattern: Manager dispatches events to appropriate machines via `mapEventToMachine()`. Machines process events via `resolve()`, emit states. Supports preconditions, error resolution, transitions

**DependencyManager:**
- Purpose: Service locator for dependency injection across plugins and state machines
- Examples: `packages/amplify_core/lib/src/state_machine/dependency_manager.dart`
- Pattern: Token-based service locator with `addBuilder()`, `addInstance()`, `get()`, `getOrCreate()`. Supports scoped child managers

**AmplifyOutputs / AmplifyConfig:**
- Purpose: Configuration models representing backend resources
- Examples: `packages/amplify_core/lib/src/config/amplify_outputs/amplify_outputs.dart`, `packages/amplify_core/lib/src/config/amplify_config.dart`
- Pattern: JSON-serializable config. Gen 2 uses `AmplifyOutputs`, Gen 1 uses `AmplifyConfig` (auto-converted to `AmplifyOutputs`)

**AmplifyException:**
- Purpose: Base exception type for all Amplify errors, includes recovery suggestions
- Examples: `packages/amplify_core/lib/src/types/exception/amplify_exception.dart`
- Pattern: Immutable, with `message`, `recoverySuggestion`, `underlyingException`. Category-specific subclasses (e.g., `AuthException`, `StorageException`)

**AmplifyHub:**
- Purpose: Pub/sub event bus for cross-category communication
- Examples: `packages/amplify_core/lib/src/hub/amplify_hub.dart`
- Pattern: Channel-based subscription. Plugins add channels with streams, consumers listen via `Amplify.Hub.listen(HubChannel.Auth, ...)`

## Entry Points

**End-User Entry (`amplify_flutter`):**
- Location: `packages/amplify/amplify_flutter/lib/amplify_flutter.dart`
- Triggers: User imports in Flutter apps
- Responsibilities: Exports `Amplify` singleton (configured for Flutter), re-exports all `amplify_core` types

**End-User Entry (`amplify_core`, Dart-only):**
- Location: `packages/amplify_core/lib/amplify_core.dart`
- Triggers: Dart-only applications or other packages
- Responsibilities: Exports `Amplify` singleton (Dart-only), all shared types, plugin interfaces

**Configuration Entry:**
- Location: `packages/amplify_core/lib/src/amplify_class.dart` (`configure()` method)
- Triggers: User calls `Amplify.configure(jsonString)`
- Responsibilities: Parses JSON config, topologically sorts categories, calls `plugin.configure()` on each

**Platform-Specific Routing:**
- Location: `packages/amplify/amplify_flutter/lib/src/amplify_impl.dart`
- Triggers: `Amplify` singleton instantiation
- Responsibilities: Returns `AmplifyHybridImpl` on iOS/Android (method channels), pure Dart impl elsewhere

## Error Handling

**Strategy:** Structured exception hierarchy with recovery suggestions

**Patterns:**
- All exceptions extend `AmplifyException` which has `message`, `recoverySuggestion`, `underlyingException`
- Category-specific exceptions: `AuthException`, `StorageException`, `ApiException`, etc.
- `ConfigurationError` (extends `AmplifyError`, not `AmplifyException`) for unrecoverable config issues
- State machines use `resolveError()` to convert errors into error states or rethrow
- `EventCompleter` captures errors with stack traces for async state machine flows
- Plugin interfaces throw `UnimplementedError` for methods not overridden by implementations

## Cross-Cutting Concerns

**Logging:**
- `AmplifyLogger` / `AWSLogger` from `aws_common` — hierarchical logger with named children
- Mixins: `AmplifyLoggerMixin`, `AWSLoggerMixin` provide `logger` getter
- State machines and plugins all use `AmplifyLoggerMixin`

**Validation:**
- Configuration validation in `AmplifyClass.configure()` — JSON decode, then parse to typed config
- Plugin method parameters validated at the category/plugin level
- State machine preconditions checked before event resolution via `checkPrecondition()`

**Authentication/Authorization:**
- `AmplifyAuthProviderRepository` shared across all categories during configuration
- Auth plugins register providers (IAM, User Pools, OIDC) that other plugins consume
- API/Storage plugins resolve auth mode and apply authorization headers automatically

**Native Interop:**
- Pigeon code generation for type-safe platform channels (iOS/Android)
- Pigeon definition files in `*/pigeons/` directories, generated code in `*/lib/src/*.g.dart`
- Packages: `amplify_auth_cognito`, `amplify_analytics_pinpoint`, `amplify_datastore`, `amplify_secure_storage`, `amplify_native_legacy_wrapper`

---

*Architecture analysis: 2026-03-07*

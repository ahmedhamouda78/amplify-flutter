# Codebase Structure

**Analysis Date:** 2026-03-07

## Directory Layout

```
amplify-flutter/
├── packages/                    # All publishable and internal packages
│   ├── amplify/                 # Top-level Amplify Flutter entry point
│   │   └── amplify_flutter/     # Flutter-specific Amplify singleton
│   ├── amplify_core/            # Core abstractions, interfaces, types
│   ├── amplify_datastore/       # DataStore plugin (native method channels)
│   ├── amplify_datastore_plugin_interface/  # Legacy DataStore interface
│   ├── amplify_foundation/      # Foundation layer (credentials, logging)
│   │   ├── amplify_foundation_dart/        # Pure Dart foundation
│   │   └── amplify_foundation_dart_bridge/ # Bridge between foundation layers
│   ├── amplify_lints/           # Custom lint rules for the repo
│   ├── amplify_native_legacy_wrapper/  # Native iOS/Android legacy wrapper
│   ├── analytics/               # Analytics category
│   │   ├── amplify_analytics_pinpoint/      # Flutter plugin (Pinpoint)
│   │   └── amplify_analytics_pinpoint_dart/ # Pure Dart plugin (Pinpoint)
│   ├── api/                     # API category (GraphQL + REST)
│   │   ├── amplify_api/         # Flutter plugin
│   │   └── amplify_api_dart/    # Pure Dart plugin
│   ├── auth/                    # Auth category
│   │   ├── amplify_auth_cognito/       # Flutter plugin (Cognito)
│   │   ├── amplify_auth_cognito_dart/  # Pure Dart plugin (Cognito)
│   │   └── amplify_auth_cognito_test/  # Shared test utilities
│   ├── authenticator/           # Pre-built auth UI
│   │   ├── amplify_authenticator/      # Flutter authenticator widget
│   │   └── amplify_authenticator_test/ # Test utilities for authenticator
│   ├── aws_common/              # AWS primitives (HTTP, credentials, logging)
│   ├── aws_signature_v4/        # AWS SigV4 request signing
│   ├── common/                  # Shared utilities
│   │   ├── amplify_db_common/          # Flutter DB helper (Drift)
│   │   └── amplify_db_common_dart/     # Pure Dart DB helper (Drift)
│   ├── example_common/          # Shared code for example apps
│   ├── notifications/           # Notifications category
│   │   └── push/
│   │       ├── amplify_push_notifications/          # Base push plugin
│   │       └── amplify_push_notifications_pinpoint/  # Pinpoint push plugin
│   ├── secure_storage/          # Secure key-value storage
│   │   ├── amplify_secure_storage/      # Flutter plugin
│   │   ├── amplify_secure_storage_dart/ # Pure Dart plugin
│   │   └── amplify_secure_storage_test/ # Shared test utilities
│   ├── smithy/                  # AWS Smithy SDK framework
│   │   ├── smithy/              # Smithy runtime library
│   │   ├── smithy_aws/          # AWS-specific Smithy extensions
│   │   ├── smithy_codegen/      # Code generator for Smithy models
│   │   ├── smithy_test/         # Test utilities for Smithy
│   │   └── goldens/             # Golden test files for codegen
│   ├── storage/                 # Storage category
│   │   ├── amplify_storage_s3/         # Flutter plugin (S3)
│   │   └── amplify_storage_s3_dart/    # Pure Dart plugin (S3)
│   ├── test/                    # Shared test packages
│   │   ├── amplify_auth_integration_test/  # Auth integration test helpers
│   │   ├── amplify_integration_test/       # General integration test helpers
│   │   ├── amplify_test/                   # Unit test helpers
│   │   └── pub_server/                     # Local pub server for testing
│   └── worker_bee/              # Web Worker / Isolate abstraction
│       ├── worker_bee/          # Runtime library
│       ├── worker_bee_builder/  # Code generator
│       ├── e2e/                 # End-to-end tests (Dart)
│       ├── e2e_flutter_test/    # End-to-end tests (Flutter)
│       └── e2e_test/            # End-to-end test definitions
│
├── aft/                         # (alias) -> packages/aft
├── actions/                     # GitHub Actions custom Dart actions
│   ├── bin/                     # Action entry points
│   ├── lib/                     # Action implementations
│   └── test/                    # Action tests
├── build-support/               # Build support scripts/configs
├── canaries/                    # Canary test app (Flutter)
│   ├── lib/                     # Canary app source
│   ├── integration_test/        # Integration tests
│   └── amplify/                 # Amplify backend config
├── infra/                       # Infrastructure-as-code (Gen 1)
│   ├── bin/                     # CDK entry points
│   └── lib/                     # CDK stack definitions
├── infra-gen2/                  # Infrastructure-as-code (Gen 2)
│   ├── backends/                # Gen 2 backend definitions
│   └── infra-common/            # Shared infra utilities
├── templates/                   # Package templates
│   ├── dart-package/            # Template for new Dart packages
│   └── flutter-package/         # Template for new Flutter packages
├── tool/                        # Repo-wide scripts
│   ├── license.sh               # License header script
│   ├── test_all_plugins.sh      # Test runner script
│   └── bump_version.dart        # Version bump utility
├── pubspec.yaml                 # Root workspace pubspec (dependency constraints)
└── pubspec.lock                 # Root lockfile
```

## Directory Purposes

**`packages/amplify_core/`:**
- Purpose: The foundational package — all abstractions, interfaces, and shared types
- Contains: `AmplifyClass`, category base classes, plugin interfaces, state machine framework, config parsing, exception hierarchy, common types (temporal, query, model)
- Key files:
  - `lib/amplify_core.dart`: Main barrel export
  - `lib/src/amplify_class.dart`: `AmplifyClass` abstract singleton
  - `lib/src/category/amplify_categories.dart`: All category classes (`AuthCategory`, `StorageCategory`, etc.)
  - `lib/src/plugin/amplify_plugin_interface.dart`: Base plugin interface
  - `lib/src/state_machine/state_machine.dart`: State machine framework
  - `lib/src/state_machine/dependency_manager.dart`: Service locator
  - `lib/src/config/amplify_outputs/amplify_outputs.dart`: Gen 2 config model

**`packages/amplify/amplify_flutter/`:**
- Purpose: The top-level package that Flutter apps depend on
- Contains: Platform-detecting `AmplifyClassImpl` factory, `AmplifyHybridImpl` for iOS/Android
- Key files:
  - `lib/amplify_flutter.dart`: Main entry point, re-exports `amplify_core`
  - `lib/src/amplify_impl.dart`: Platform-detecting factory
  - `lib/src/hybrid_impl.dart`: Method channel routing for native plugins

**`packages/auth/amplify_auth_cognito_dart/`:**
- Purpose: Pure Dart Cognito auth implementation (works on all platforms)
- Contains: Auth plugin, state machines (sign-in, sign-up, sign-out, credential store, etc.), SDK clients, hosted UI flows
- Key files:
  - `lib/src/auth_plugin_impl.dart`: `AmplifyAuthCognitoDart` plugin class
  - `lib/src/state/cognito_state_machine.dart`: Root state machine manager
  - `lib/src/state/machines/`: Individual state machines (`sign_in_state_machine.dart`, etc.)
  - `lib/src/sdk/`: Smithy-generated Cognito SDK client wrappers
  - `lib/src/flows/`: Auth flow implementations (SRP, hosted UI)
  - `lib/src/credentials/`: Credential and device metadata management

**`packages/auth/amplify_auth_cognito/`:**
- Purpose: Flutter wrapper adding native iOS/Android support to the Dart auth plugin
- Contains: Native plugin bridge, legacy credential migration, hosted UI platform implementation
- Key files:
  - `lib/src/auth_plugin_impl.dart`: `AmplifyAuthCognito extends AmplifyAuthCognitoDart`
  - `lib/src/native_auth_plugin.g.dart`: Pigeon-generated native bridge
  - `pigeons/native_plugin.dart`: Pigeon interface definition

**`packages/api/amplify_api_dart/`:**
- Purpose: Pure Dart API plugin (GraphQL + REST)
- Contains: GraphQL request handling, WebSocket subscription management, REST client, auth decorators
- Key files:
  - `lib/src/api_plugin_impl.dart`: `AmplifyAPIDart` plugin class
  - `lib/src/graphql/`: GraphQL helpers, WebSocket BLoC for subscriptions
  - `lib/src/decorators/`: Request authorization decorators

**`packages/storage/amplify_storage_s3_dart/`:**
- Purpose: Pure Dart S3 storage implementation
- Contains: Upload/download operations, multipart transfer management, path resolution
- Key files:
  - `lib/src/amplify_storage_s3_dart_impl.dart`: `AmplifyStorageS3Dart` plugin class
  - `lib/src/storage_s3_service/`: Core S3 service and transfer management
  - `lib/src/path_resolver/`: S3 path resolution logic

**`packages/smithy/`:**
- Purpose: AWS Smithy model SDK — runtime and code generator for AWS service clients
- Contains: Smithy model AST, Dart code generator, serialization protocols, HTTP operations
- Key files:
  - `smithy/lib/src/`: Runtime types (endpoint, operation, serialization, protocol, HTTP)
  - `smithy_aws/lib/src/`: AWS-specific protocols (restJson1, restXml, etc.)
  - `smithy_codegen/lib/src/`: Code generator (model → Dart source)
  - `goldens/`: Golden test reference files

**`packages/aws_common/`:**
- Purpose: Foundational AWS types shared by everything
- Contains: HTTP client abstractions (platform-specific IO/JS), credentials, logging, collections, config
- Key files:
  - `lib/src/http/`: `AWSHttpClient`, `AWSHttpRequest`, `AWSHttpResponse`, platform impls
  - `lib/src/logging/`: `AWSLogger` logging framework
  - `lib/src/credentials/`: `AWSCredentials` type

**`packages/authenticator/amplify_authenticator/`:**
- Purpose: Drop-in Flutter authenticator UI widget
- Contains: BLoC state management, screens, form widgets, l10n, theme support
- Key files:
  - `lib/src/blocs/`: Auth BLoC for state management
  - `lib/src/screens/`: Sign-in, sign-up, confirm screens
  - `lib/src/widgets/`: Form fields, buttons, layout widgets
  - `lib/src/l10n/`: Internationalization

**`packages/aft/` (Amplify Flutter Tool):**
- Purpose: Internal CLI tool for repo management (versioning, publishing, constraints checking)
- Contains: Commands for version bumps, changelog generation, dependency constraint verification
- Key files:
  - `lib/src/command_runner.dart`: CLI entry point
  - `lib/src/commands/`: Individual commands
  - `lib/src/repo.dart`: Repo model and package discovery

## Key File Locations

**Entry Points:**
- `packages/amplify/amplify_flutter/lib/amplify_flutter.dart`: Flutter app entry point
- `packages/amplify_core/lib/amplify_core.dart`: Dart-only entry point
- `packages/amplify_core/lib/src/amplify_class.dart`: `AmplifyClass` singleton definition

**Configuration:**
- `pubspec.yaml`: Root workspace with global dependency constraints and `aft` configuration
- `packages/amplify_core/lib/src/config/amplify_outputs/amplify_outputs.dart`: Gen 2 config model
- `packages/amplify_core/lib/src/config/amplify_config.dart`: Gen 1 config model
- `packages/amplify_core/lib/src/config/amplify_plugin_registry.dart`: Plugin config registry

**Core Logic:**
- `packages/amplify_core/lib/src/category/amplify_categories.dart`: All category base classes
- `packages/amplify_core/lib/src/plugin/`: All plugin interface definitions
- `packages/amplify_core/lib/src/state_machine/state_machine.dart`: State machine framework
- `packages/amplify_core/lib/src/state_machine/dependency_manager.dart`: DI/service locator

**Testing:**
- `packages/test/amplify_test/lib/`: Shared unit test utilities
- `packages/test/amplify_integration_test/lib/`: Integration test helpers
- `packages/test/amplify_auth_integration_test/lib/`: Auth-specific integration test helpers
- `packages/auth/amplify_auth_cognito_test/lib/`: Auth Cognito shared test utilities
- `packages/authenticator/amplify_authenticator_test/lib/`: Authenticator shared test utilities
- `packages/secure_storage/amplify_secure_storage_test/lib/`: Secure storage shared test utilities

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart files
- `*_impl.dart` for implementation classes (e.g., `auth_plugin_impl.dart`, `amplify_impl.dart`)
- `*.g.dart` for generated files (JSON serialization, Pigeon bindings)
- `*_test.dart` for test files

**Packages:**
- `amplify_<category>_<service>` for Flutter plugins (e.g., `amplify_auth_cognito`, `amplify_storage_s3`)
- `amplify_<category>_<service>_dart` for pure Dart plugins (e.g., `amplify_auth_cognito_dart`)
- `amplify_<category>_<service>_test` for shared test utilities
- Service names match AWS service names: `cognito`, `s3`, `pinpoint`

**Directories:**
- Category packages grouped in parent directories: `auth/`, `storage/`, `api/`, `analytics/`, `notifications/`
- `lib/src/` for implementation code (private by convention)
- `lib/<package_name>.dart` as the barrel export file
- `pigeons/` for Pigeon interface definitions
- `example/` for example apps within each package

**Classes:**
- `Amplify<Category><Service>` for Flutter plugins (e.g., `AmplifyAuthCognito`)
- `Amplify<Category><Service>Dart` for Dart plugins (e.g., `AmplifyAuthCognitoDart`)
- Flutter plugin extends Dart plugin (e.g., `AmplifyAuthCognito extends AmplifyAuthCognitoDart`)
- `<Category>Category` for category classes (e.g., `AuthCategory`)
- `<Category>PluginInterface` for plugin interfaces (e.g., `AuthPluginInterface`)

## Where to Add New Code

**New Amplify Category:**
1. Add plugin interface: `packages/amplify_core/lib/src/plugin/amplify_<category>_plugin_interface.dart`
2. Add category class: `packages/amplify_core/lib/src/category/amplify_<category>_category.dart` (as a `part` of `amplify_categories.dart`)
3. Add types: `packages/amplify_core/lib/src/types/<category>/`
4. Add config: `packages/amplify_core/lib/src/config/<category>/`
5. Create Dart plugin: `packages/<category>/amplify_<category>_<service>_dart/`
6. Create Flutter plugin: `packages/<category>/amplify_<category>_<service>/`
7. Register in `AmplifyClassImpl.addPluginPlatform()` and `AmplifyHybridImpl.addPluginPlatform()`
8. Add to `Category` enum in `packages/amplify_core/lib/src/category/amplify_categories.dart`

**New Feature in Existing Category (e.g., new auth operation):**
1. Add abstract method to plugin interface: `packages/amplify_core/lib/src/plugin/amplify_<category>_plugin_interface.dart`
2. Add delegation in category: `packages/amplify_core/lib/src/category/amplify_<category>_category.dart`
3. Implement in Dart plugin: `packages/<category>/amplify_<category>_<service>_dart/lib/src/<plugin>_impl.dart`
4. Add state machine if complex: `packages/<category>/amplify_<category>_<service>_dart/lib/src/state/machines/`
5. Add types: `packages/amplify_core/lib/src/types/<category>/`
6. Tests: co-located `test/` directory in the implementing package

**New AWS SDK Client (via Smithy):**
1. Add Smithy model: update relevant model files
2. Generate via `smithy_codegen`: outputs to the plugin's `lib/src/sdk/` directory
3. SDK clients are stored within the consuming plugin package, not globally

**New Shared Utility:**
- For AWS-level utilities: `packages/aws_common/lib/src/`
- For Amplify-level utilities: `packages/amplify_core/lib/src/util/`
- For package-specific utilities: `packages/<category>/amplify_<category>_<service>_dart/lib/src/util/`

**New Example App:**
- In the relevant package: `packages/<category>/amplify_<category>_<service>/example/`

**New Test Package:**
- Shared test utilities: `packages/test/amplify_<name>_test/`
- Category-specific test utilities: `packages/<category>/amplify_<category>_<service>_test/`

## Special Directories

**`packages/smithy/goldens/`:**
- Purpose: Golden test reference outputs for the Smithy code generator
- Generated: Yes (reference output for validation)
- Committed: Yes

**`packages/aft/`:**
- Purpose: Internal repo management CLI (Amplify Flutter Tool)
- Generated: No
- Committed: Yes

**`infra/` and `infra-gen2/`:**
- Purpose: CDK infrastructure definitions for integration test backends
- Generated: No
- Committed: Yes

**`actions/`:**
- Purpose: Custom GitHub Actions written in Dart
- Generated: No
- Committed: Yes

**`canaries/`:**
- Purpose: Canary test Flutter app for smoke testing
- Generated: No
- Committed: Yes

**`templates/`:**
- Purpose: Scaffolding templates for creating new packages
- Generated: No
- Committed: Yes

**`tool/`:**
- Purpose: Repo-wide shell scripts and Dart tools
- Generated: No
- Committed: Yes

**`build-support/`:**
- Purpose: Build support configuration files
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-03-07*

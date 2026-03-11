# Technology Stack

**Analysis Date:** 2026-03-07

## Languages

**Primary:**
- Dart ^3.9.0 - All SDK packages, core logic, plugin implementations, tooling (`packages/aft/`)
- Flutter >=3.35.0 - Flutter-specific plugin wrappers and UI components

**Secondary:**
- Kotlin - Android platform channel implementations (`packages/auth/amplify_auth_cognito/android/src/main/kotlin/`, `packages/amplify_datastore/android/`, `packages/notifications/push/amplify_push_notifications/android/`)
- Swift - iOS/macOS platform channel implementations (`packages/auth/amplify_auth_cognito/darwin/Classes/`)
- Java - Legacy Android Pigeon-generated bindings (`packages/analytics/amplify_analytics_pinpoint/android/src/main/java/`)
- TypeScript ~5.8.3 - Infrastructure-as-code for integration test backends (`infra/`)

## Runtime

**Environment:**
- Dart SDK ^3.9.0
- Flutter SDK >=3.35.0

**Package Manager:**
- pub (Dart/Flutter) - Primary dependency management
- pnpm - For `infra/` TypeScript project
- Lockfile: `pubspec.lock` present at repo root; `pnpm-lock.yaml` in `infra/`

## Frameworks

**Core:**
- Flutter >=3.35.0 - Cross-platform UI framework (iOS, Android, macOS, Windows, Linux, Web)
- AWS Amplify (Dart implementation) - The product this repo implements

**Testing:**
- `test` ^1.22.1 - Standard Dart test runner for all Dart-only packages
- `flutter_test` (SDK) - Flutter widget and unit testing
- `integration_test` (SDK) - E2E/integration testing on devices (`canaries/integration_test/`)
- `golden_toolkit` ^0.15.0 - Golden/snapshot tests for UI (`packages/authenticator/`)
- `jest` ^30.2.0 - CDK infrastructure tests (`infra/jest.config.js`)

**Build/Dev:**
- `build_runner` ^2.4.15 - Dart code generation orchestrator
- `json_serializable` ^6.11.0 - JSON serialization code generation
- `built_value` ^8.10.1 / `built_value_generator` ^8.10.1 - Immutable value types with code gen
- `drift` ^2.25.0 / `drift_dev` ^2.25.1 - SQLite database abstraction with code gen
- `pigeon` ^26.0.0 - Type-safe Flutter platform channel code generation (Dart <-> Kotlin/Swift)
- `ffigen` ^9.0.0 - Dart FFI bindings generation for native C libraries
- `worker_bee_builder` - Custom builder for cross-platform isolated worker code gen
- `smithy_codegen` - Custom Smithy-based AWS SDK client code generation (in-repo at `packages/smithy/smithy_codegen/`)
- `aws-cdk` 2.1109.0 / `aws-cdk-lib` 2.241.0 - Infrastructure provisioning for integration test backends (`infra/`)
- `mason` ^0.1.1 - Template-based code generation for new packages (`templates/`)

**Linting:**
- `amplify_lints` 3.1.4 - Custom lint package extending `flutter_lints` and `lints` (`packages/amplify_lints/`)

## Key Dependencies

**Critical (shipped to consumers):**
- `aws_common` 0.7.12 - Common AWS types: HTTP client, credentials, serialization (`packages/aws_common/`)
- `aws_signature_v4` 0.6.10 - AWS SigV4 signing for all AWS API requests (`packages/aws_signature_v4/`)
- `amplify_core` 2.10.1 - Base types, plugin interface, config, categories, state machines (`packages/amplify_core/`)
- `smithy` 0.7.10 - Smithy client runtime for Dart I/O and serialization (`packages/smithy/smithy/`)
- `smithy_aws` 0.7.10 - AWS-specific Smithy runtime: endpoint resolution, retry, SigV4 (`packages/smithy/smithy_aws/`)

**Infrastructure:**
- `built_value` ^8.10.1 - Immutable value types used pervasively in Smithy-generated SDK code
- `drift` ^2.25.0 - SQLite ORM for local data persistence (analytics event cache, storage transfer DB)
- `sqlite3` ^2.7.6 - SQLite3 native bindings for Drift on non-Flutter platforms (`packages/common/amplify_db_common_dart/`)
- `http` ^1.3.0 - HTTP client used in `aws_common`
- `http2` ^2.0.0 - HTTP/2 support in `aws_common`
- `web_socket_channel` ^3.0.3 - WebSocket support for GraphQL subscriptions (`packages/api/amplify_api_dart/`)
- `oauth2` ^2.0.2 - OAuth2 hosted UI token exchange in auth (`packages/auth/amplify_auth_cognito_dart/`)
- `crypto` ^3.0.7 - Cryptographic operations for SigV4 and SRP auth flows
- `ffi` ^2.0.2 - Dart FFI for native platform interop (secure storage on desktop)
- `win32` ^5.14.0 - Windows API bindings for secure storage and auth (`packages/secure_storage/amplify_secure_storage_dart/`)
- `connectivity_plus` ^7.0.0 - Network connectivity detection for API plugin (`packages/api/amplify_api/`)
- `device_info_plus` ^12.0.0 - Device info for analytics (`packages/analytics/amplify_analytics_pinpoint/`)
- `package_info_plus` ^9.0.0 - App package metadata for analytics and authenticator

**Mocking (dev):**
- `mocktail` ^1.0.0 - Mock library (most packages)
- `mockito` ^5.0.0 - Mock library (auth cognito dart, push notifications)

## Monorepo Tooling

**`aft` (Amplify Flutter Tool):**
- Location: `packages/aft/`
- Purpose: Custom CLI for monorepo management (version bumping, dependency linking, workflow generation, formatting, analysis)
- Key commands: `aft link` (symlink local deps), `aft generate workflows` (CI yaml), `aft format`, `aft analyze`, `aft version-bump`
- Config: `aft:` section in root `pubspec.yaml`

**Strongly Connected Components:**
- Packages are grouped into version-bump components defined in root `pubspec.yaml` under `aft.components`
- Major groups: "Amplify Flutter" (8 packages), "Amplify Dart" (4 packages), "AWS Common" (2 packages), "Smithy" (2 packages), "Secure Storage" (2 packages), "Worker Bee" (2 packages), "DB Common" (2 packages), "Amplify UI" (1 package)

## Configuration

**Environment:**
- Amplify apps are configured via `AmplifyConfig` / `amplify_outputs.dart` JSON configuration loaded at runtime
- Config schema defined in `packages/amplify_core/lib/src/config/`
- No `.env` files in repo (secrets are managed externally for integration tests)

**Build:**
- `pubspec.yaml` - Per-package dependency and metadata
- `analysis_options.yaml` - Per-package lint configuration (extends `amplify_lints`)
- `build.yaml` - Per-package code generation configuration (where applicable)
- `dart_test.yaml` - Test runner configuration for some packages
- `pigeons/` directories - Pigeon IDL files for platform channel generation

## Platform Requirements

**Development:**
- Dart SDK ^3.9.0
- Flutter SDK >=3.35.0
- For Android plugins: Android SDK, minSdkVersion 24
- For iOS/macOS plugins: Xcode, iOS >=13.0, macOS >=10.15
- For Windows: win32 API access
- For infrastructure: Node.js, pnpm, AWS CDK CLI, AWS credentials

**Production (consumer apps):**
- Supported platforms: iOS, Android, macOS, Windows, Linux, Web
- Dart-only (`_dart`) packages work on all Dart platforms without Flutter
- Flutter packages require Flutter runtime
- DataStore plugin: iOS and Android only (native Amplify SDK dependency)
- Push Notifications: iOS and Android only

---

*Stack analysis: 2026-03-07*

# External Integrations

**Analysis Date:** 2026-03-07

## APIs & External Services

**Authentication - AWS Cognito:**
- Service: Amazon Cognito User Pools + Identity Pools
- SDK/Client: Smithy-generated Dart client at `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/src/cognito_identity_provider/` and `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/src/cognito_identity/`
- Dart plugin: `packages/auth/amplify_auth_cognito_dart/` (pure Dart)
- Flutter plugin: `packages/auth/amplify_auth_cognito/` (adds native platform channels for hosted UI via ASWebAuthenticationSession/Custom Tabs)
- Auth: Configured via `AmplifyConfig` JSON with Cognito User Pool ID, App Client ID, Identity Pool ID
- Features: Sign up, sign in (SRP, custom, device SRP), MFA (SMS, TOTP), OAuth/hosted UI, federation, password reset, user attributes, device tracking

**Analytics - AWS Pinpoint:**
- Service: Amazon Pinpoint
- SDK/Client: Smithy-generated Dart client at `packages/analytics/amplify_analytics_pinpoint_dart/lib/src/sdk/src/pinpoint/`
- Dart plugin: `packages/analytics/amplify_analytics_pinpoint_dart/`
- Flutter plugin: `packages/analytics/amplify_analytics_pinpoint/`
- Auth: Uses Cognito Identity Pool credentials (auto-resolved via auth plugin)
- Features: Event recording, endpoint management, session tracking, event batching with local SQLite cache

**Storage - AWS S3:**
- Service: Amazon S3
- SDK/Client: Smithy-generated Dart client at `packages/storage/amplify_storage_s3_dart/lib/src/sdk/src/s3/`
- Dart plugin: `packages/storage/amplify_storage_s3_dart/`
- Flutter plugin: `packages/storage/amplify_storage_s3/`
- Auth: Uses Cognito Identity Pool credentials
- Features: Upload (single-part, multipart), download, list, remove, copy, getUrl, getProperties; local transfer database via Drift/SQLite for resumable transfers

**API - AWS AppSync (GraphQL) & API Gateway (REST):**
- Service: AWS AppSync (GraphQL), Amazon API Gateway (REST)
- SDK/Client: Custom HTTP/WebSocket client (not Smithy-generated)
- Dart plugin: `packages/api/amplify_api_dart/`
- Flutter plugin: `packages/api/amplify_api/`
- Auth: IAM (SigV4), Cognito User Pools (JWT), API Key, Lambda authorizer
- Features: GraphQL query/mutation/subscription (WebSocket), REST GET/POST/PUT/DELETE/PATCH/HEAD
- WebSocket: `web_socket_channel` ^3.0.3 for real-time GraphQL subscriptions

**DataStore - AWS AppSync (Sync):**
- Service: AWS AppSync (for cloud sync)
- SDK/Client: Native Amplify iOS/Android SDKs via platform channels
- Plugin: `packages/amplify_datastore/`
- Auth: Configured via Amplify backend
- Features: On-device data store with offline-first sync, conflict resolution; iOS and Android only
- Note: Uses native Amplify SDKs under the hood, not pure Dart

**Push Notifications - AWS Pinpoint + FCM/APNs:**
- Service: Amazon Pinpoint (campaign orchestration), Firebase Cloud Messaging (Android), Apple Push Notification service (iOS)
- Plugin: `packages/notifications/push/amplify_push_notifications/` (base), `packages/notifications/push/amplify_push_notifications_pinpoint/` (Pinpoint provider)
- Auth: Cognito Identity Pool credentials for Pinpoint API calls
- Features: Token registration, notification handling, campaign analytics; iOS and Android only

## Data Storage

**Local Databases:**
- Drift (SQLite ORM) ^2.25.0 - Used by analytics (event cache) and storage (transfer tracking)
  - Analytics DB: `packages/analytics/amplify_analytics_pinpoint_dart/`
  - Storage DB: `packages/storage/amplify_storage_s3_dart/`
  - DB common utilities: `packages/common/amplify_db_common_dart/` and `packages/common/amplify_db_common/`
  - SQLite3 native bindings: `sqlite3` ^2.7.6 via `amplify_db_common_dart`
  - Web: IndexedDB via Drift's web adapter

**Secure Storage:**
- `packages/secure_storage/amplify_secure_storage_dart/` - Dart-only, uses platform-specific backends:
  - macOS/iOS: Keychain (via FFI)
  - Linux: libsecret (via FFI)
  - Windows: Windows Credential Manager (via `win32`)
  - Web: Web Storage API (sessionStorage/localStorage) with optional Web Workers
  - Android: Not supported in dart-only package
- `packages/secure_storage/amplify_secure_storage/` - Flutter wrapper, adds Android support via EncryptedSharedPreferences (platform channel)

**File Storage:**
- Local filesystem via `path_provider` for:
  - Download cache in storage plugin (`packages/storage/amplify_storage_s3/`)
  - SQLite database files

**Caching:**
- No external caching service
- In-memory caching for auth tokens/credentials in `amplify_auth_cognito_dart`
- SQLite-backed event queue for analytics (batched flush to Pinpoint)
- SQLite-backed transfer database for storage (resumable uploads/downloads)

## Authentication & Identity

**Auth Provider: AWS Cognito**
- Implementation: Custom Dart implementation of Cognito auth flows (SRP, hosted UI, device SRP)
- SRP (Secure Remote Password): Fully implemented in Dart at `packages/auth/amplify_auth_cognito_dart/lib/src/flows/`
- Hosted UI: Native platform integration via ASWebAuthenticationSession (iOS/macOS) and Custom Tabs (Android)
  - iOS/macOS: `packages/auth/amplify_auth_cognito/darwin/Classes/HostedUIFlow.swift`
  - Android: `packages/auth/amplify_auth_cognito/android/src/main/kotlin/.../AmplifyAuthCognitoPlugin.kt`
- Token management: JWT access/ID/refresh tokens managed in `amplify_auth_cognito_dart`
- Credential provider: Cognito Identity Pool for vending temporary AWS credentials (IAM)

**Auth signing for AWS APIs:**
- AWS Signature V4: `packages/aws_signature_v4/` - Signs all HTTP requests to AWS services
- Auth provider repository: `packages/amplify_core/lib/src/types/common/amplify_auth_provider.dart`

## Monitoring & Observability

**Error Tracking:**
- No external error tracking service integrated
- Custom error types defined per category in `amplify_core`

**Logs:**
- `AWSLogger` / `AmplifyLogger` in `packages/amplify_core/lib/src/logger/`
- Uses Dart `logging` ^1.0.0 package
- Hierarchical namespace-based logging (e.g., `Amplify.Auth.Cognito`)
- Consumers can attach custom `AmplifyLoggerPlugin` implementations

## CI/CD & Deployment

**Hosting:**
- Published to pub.dev (Dart/Flutter package registry)
- 99 GitHub Actions workflow files in `.github/workflows/`

**CI Pipeline: GitHub Actions**
- Workflows auto-generated via `aft generate workflows` from package metadata
- Per-package workflows for: unit tests, Android tests, iOS tests, example builds
- Platform-specific test matrices: `dart_native.yaml`, `dart_vm.yaml`, `flutter_vm.yaml`, `flutter_android.yaml`, `flutter_ios.yaml`
- E2E test workflows: `e2e_android.yaml`, `e2e_ios.yaml`, `e2e_linux.yaml`, `e2e_web.yaml`, `e2e_windows.yaml`
- Smithy protocol test workflows (multiple): `aws_json1_0_v1.yaml`, `rest_json1_v1.yaml`, etc.
- Canary app: `amplify_canaries.yaml` / `canaries/` - Integration test app exercising all categories

**Infrastructure Provisioning:**
- AWS CDK (TypeScript) at `infra/` - Provisions Cognito, S3, AppSync, API Gateway, Pinpoint backends for integration tests
- Deploy: `pnpm run deploy` in `infra/`
- Gen2 backends: `infra-gen2/` - Additional integration test backends

## Environment Configuration

**Required for development:**
- No env vars required for basic development/unit testing
- Integration tests require AWS backend configuration (generated via CDK deploy into `amplifyconfiguration.dart` files)

**Required for integration testing:**
- AWS credentials/profile for CDK deployment
- `AWS_PROFILE` - AWS CLI profile for CDK operations (`infra/package.json`)
- Backend configs generated by `infra/tool/create_configs.dart` after CDK deploy

**Secrets location:**
- No secrets committed to repo
- Integration test configs use generated `amplifyconfiguration.dart` files (gitignored)
- CI secrets managed via GitHub Actions secrets

## Webhooks & Callbacks

**Incoming:**
- OAuth redirect URIs for Cognito Hosted UI (deep links handled by native platform code)
- Push notification token callbacks from FCM/APNs (handled by native plugins)

**Outgoing:**
- None (this is a client SDK, not a server)

## Smithy Code Generation (AWS SDK Clients)

**Custom in-repo Smithy toolchain:**
- Smithy IDL models define AWS service APIs
- Code generator: `packages/smithy/smithy_codegen/` - Generates Dart client code from Smithy models
- Runtime: `packages/smithy/smithy/` - Client runtime (serialization, HTTP, retry)
- AWS runtime: `packages/smithy/smithy_aws/` - AWS-specific behaviors (SigV4, endpoint resolution, S3 customizations)
- Protocol tests: `packages/smithy/goldens/` - Golden files for generated code validation
- Generated clients live inside each category package's `lib/src/sdk/src/` directory

**AWS Services with generated Dart clients:**
| Service | Location |
|---------|----------|
| Cognito Identity Provider | `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/src/cognito_identity_provider/` |
| Cognito Identity | `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/src/cognito_identity/` |
| Pinpoint | `packages/analytics/amplify_analytics_pinpoint_dart/lib/src/sdk/src/pinpoint/` |
| S3 | `packages/storage/amplify_storage_s3_dart/lib/src/sdk/src/s3/` |

## Platform Channel Interfaces (Pigeon)

**Pigeon-generated type-safe platform channels:**
- Auth Cognito: `packages/auth/amplify_auth_cognito/pigeons/` -> Kotlin/Swift bindings for hosted UI
- DataStore: `packages/amplify_datastore/pigeons/` -> Kotlin/Swift bindings for native DataStore SDK
- Push Notifications: `packages/notifications/push/amplify_push_notifications/pigeons/` -> Kotlin/Swift bindings for FCM/APNs
- Analytics Pinpoint: `packages/analytics/amplify_analytics_pinpoint/pigeons/` -> Kotlin bindings
- Native Legacy Wrapper: `packages/amplify_native_legacy_wrapper/pigeons/` -> Wraps legacy native Amplify SDK APIs

---

*Integration audit: 2026-03-07*

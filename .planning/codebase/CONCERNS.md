# Codebase Concerns

**Analysis Date:** 2026-03-07

## Tech Debt

**DataStore MethodChannel Legacy Architecture:**
- Issue: `amplify_datastore` still uses Flutter's MethodChannel/EventChannel for native bridge communication. This is a legacy pattern that other packages have migrated away from (e.g., auth uses Pigeon-generated bindings). The code uses `dynamic` extensively for message passing and relies on manual serialization/deserialization of maps.
- Files: `packages/amplify_datastore/lib/src/method_channel_datastore.dart`, `packages/amplify_datastore/lib/amplify_datastore.dart`
- Impact: Type-unsafe communication with native layer. The `as dynamic` cast on line 269 of `amplify_datastore.dart` to access auth session properties bypasses type checking entirely. Manual map serialization is error-prone.
- Fix approach: Migrate to Pigeon-based code generation for type-safe native communication, consistent with other packages like `amplify_auth_cognito` and `amplify_secure_storage`.

**Dart DDC Yield Bug Workarounds:**
- Issue: At least 10 locations in the WebSocket bloc contain `yield* const Stream.empty()` as a workaround for a Dart DDC (dev compiler) bug where yield is broken in web debug builds. The authenticator bloc has the same workaround.
- Files: `packages/api/amplify_api_dart/lib/src/graphql/web_socket/blocs/web_socket_bloc.dart` (lines 315, 326, 338, 348, 354, 365, 409, 444, 456, 601), `packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart` (line 176)
- Impact: Code clutter, potential confusion for contributors, and masks a fundamental compiler issue that may affect other async generators. If the DDC bug is fixed upstream, these workarounds become dead code.
- Fix approach: Track the upstream Dart SDK issue. Once resolved, remove all `yield* const Stream.empty()` workarounds. Consider adding a lint or comment convention to make these easier to find.

**Massive Generated macOS Bindings File:**
- Issue: A single FFI bindings file is 26,147 lines, generated via ffigen for macOS Keychain/Security framework access.
- Files: `packages/auth/amplify_auth_cognito_dart/lib/src/platform/macos_bindings.g.dart`
- Impact: Inflates package size significantly. Slows IDE indexing and analysis. Only a small subset of the bindings are actually used (primarily for ASF device info collection on macOS).
- Fix approach: Configure ffigen to generate only the required symbols/types instead of the entire Security framework. See `packages/auth/amplify_auth_cognito_dart/ffigen.macos.yaml` for current config.

**Pre-1.0 Core Dependencies:**
- Issue: Many foundational packages remain at version 0.x, indicating unstable API surfaces. This includes: `aws_common` (0.7.12), `aws_signature_v4` (0.6.10), `amplify_auth_cognito_dart` (0.11.18), `amplify_api_dart` (0.5.16), `amplify_storage_s3_dart` (0.4.17), `amplify_secure_storage_dart` (0.5.10), `amplify_db_common_dart` (0.4.16), all smithy packages.
- Files: Various `pubspec.yaml` files across the monorepo
- Impact: Semver allows breaking changes in 0.x releases, creating churn for consumers. Inter-package version constraints are very tight (e.g., `">=2.10.0 <2.11.0"`), requiring coordinated releases across the entire monorepo.
- Fix approach: Stabilize core packages (`aws_common`, `aws_signature_v4`) first, then work outward to category plugins. The publish command in `packages/aft/lib/src/commands/publish_command.dart` has a TODO noting this should be addressed before 1.0.

**Passwordless/Passkey Authentication Not Implemented:**
- Issue: The authenticator UI widget has TODO stubs for passwordless (WebAuthn/passkey) authentication. When this sign-in step is encountered, it throws a user-facing error: "Passwordless is not supported at this time."
- Files: `packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart` (line 267), `packages/authenticator/amplify_authenticator/lib/src/services/amplify_auth_service.dart` (lines 29, 157), `packages/amplify_core/lib/src/types/auth/sign_in/auth_factor_type.dart` (line 28)
- Impact: Users configuring Cognito with passwordless flows will get runtime errors in the Authenticator widget. This is a gap compared to the React Authenticator.
- Fix approach: Implement WebAuthn/passkey support per the linked AWS docs.

**Incomplete Username Regex Validation:**
- Issue: The username regex in the authenticator does not match Cognito's actual requirements. A TODO notes that the proposed Unicode-aware expression `[\p{L}\p{M}\p{S}\p{N}\p{P}]+` does not work due to Dart regex flavor differences.
- Files: `packages/authenticator/amplify_authenticator/lib/src/utils/validators.dart` (line 11)
- Impact: Client-side validation may reject valid usernames or accept invalid ones, leading to confusing error messages from Cognito.
- Fix approach: Investigate Dart's Unicode regex support and align with Cognito's actual validation rules.

**Legacy Native Wrapper Package:**
- Issue: `amplify_native_legacy_wrapper` exists as a bridge to v1 Amplify native SDKs. The package is at version 0.0.1 and wraps legacy Kotlin/Swift Amplify plugins via Pigeon.
- Files: `packages/amplify_native_legacy_wrapper/lib/amplify_native_legacy_wrapper.dart`, `packages/amplify_native_legacy_wrapper/pigeons/messages.dart`
- Impact: Carries forward technical debt from the previous architecture. Used by analytics for legacy data migration (`packages/analytics/amplify_analytics_pinpoint/lib/src/flutter_endpoint_info_store_manager.dart`).
- Fix approach: Complete migration away from legacy native SDKs, then deprecate and remove this package.

**S3 Payload Signing Disabled:**
- Issue: S3 upload payload signing is explicitly disabled because the signer does not support hashing on different threads.
- Files: `packages/storage/amplify_storage_s3_dart/lib/src/storage_s3_service/service/storage_s3_service_impl.dart` (line 95-98)
- Impact: Unsigned payloads are less secure, particularly for non-HTTPS connections (though S3 enforces HTTPS). This is a deviation from best practices.
- Fix approach: Implement multi-threaded hashing support in the signer, then re-enable `signPayload: true`.

## Known Bugs

**Storage Download Cancellation Failing on Web:**
- Symptoms: Download file and download data cancellation tests fail on Flutter web since Flutter v3.22.
- Files: `packages/storage/amplify_storage_s3/example/integration_test/download_file_test.dart` (lines 301, 236, 306), `packages/storage/amplify_storage_s3/example/integration_test/download_data_test.dart` (line 232)
- Trigger: Call `operation.cancel()` on a download operation running in a web environment.
- Workaround: Tests are skipped with `skip: true`.

**Temporal Types Failing on Web:**
- Symptoms: `AmplifyTemporalDate`, `AmplifyTemporalDateTime`, `AmplifyTemporalTime`, and `AmplifyTemporalTimestamp` tests all fail when run in a browser.
- Files: `packages/amplify_core/test/amplify_temporal_date_test.dart`, `packages/amplify_core/test/amplify_temporal_datetime_test.dart`, `packages/amplify_core/test/amplify_temporal_time_test.dart`, `packages/amplify_core/test/amplify_temporal_timestamp_test.dart`, `packages/amplify_core/test/amplify_utility_test.dart`
- Trigger: Run tests with `@OnPlatform(<String, Object>{'browser': Skip('Failing on web')})`.
- Workaround: Tests are skipped on web platform.

**Analytics Retry Logic Over-Broad:**
- Symptoms: The analytics event client retries events that receive non-5xx status codes, which may not be retryable.
- Files: `packages/analytics/amplify_analytics_pinpoint_dart/test/event_client_test.dart` (lines 302, 346)
- Trigger: Any failed event push that returns a non-2xx status code.
- Workaround: None documented. TODO notes suggest retryable exceptions should only be status code >=500 <600.

**Authenticator Event Handling Bug on Web:**
- Symptoms: Broken event handling in the authenticator state machine on web, possibly a DDC issue.
- Files: `packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart` (line 176)
- Trigger: Auth flow state transitions on web platform.
- Workaround: `yield* const Stream.empty()` inserted to work around the issue.

## Security Considerations

**Dynamic Casting for Auth Session in DataStore:**
- Risk: The DataStore plugin casts `Amplify.Auth.fetchAuthSession()` result to `dynamic` and then accesses properties without type safety. A changed auth session interface would cause silent failures at runtime.
- Files: `packages/amplify_datastore/lib/amplify_datastore.dart` (line 269)
- Current mitigation: The cast works because the auth plugin always returns `CognitoAuthSession`, but this coupling is implicit.
- Recommendations: Add a typed interface or use the plugin key pattern (`Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey)`) to get a properly typed session.

**Broad `ignore: implementation_imports` Suppression:**
- Risk: Multiple packages import implementation details from other packages (30+ files). These internal APIs can change without notice, potentially breaking functionality silently.
- Files: `packages/authenticator/amplify_authenticator_test/lib/src/pages/*.dart` (11+ files), `packages/amplify/amplify_flutter/lib/src/amplify_impl.dart`, `packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart`, `packages/api/amplify_api_dart/lib/src/graphql/web_socket/blocs/web_socket_bloc.dart`
- Current mitigation: Analysis options in some packages suppress the lint entirely.
- Recommendations: Promote frequently-used internal APIs to public `@visibleForTesting` or `@internal` exports. Reduce cross-package implementation imports.

**Sensitive Data in Secure Storage:**
- Risk: Secure storage implementations span multiple platforms with different security models (Keychain on macOS/iOS, DPAPI on Windows, IndexedDB on web). The web implementation inherently has weaker security guarantees.
- Files: `packages/secure_storage/amplify_secure_storage_dart/lib/src/platforms/amplify_secure_storage_web.dart`, `packages/secure_storage/amplify_secure_storage_dart/lib/src/platforms/amplify_secure_storage_windows.dart`, `packages/secure_storage/amplify_secure_storage_dart/lib/src/ffi/win32/data_protection.dart`
- Current mitigation: Platform-specific implementations use native security APIs where available.
- Recommendations: Document security limitations of web storage clearly. Consider encrypted storage fallback for web.

## Performance Bottlenecks

**Large Generated Code Volume:**
- Problem: 1,375 generated `.g.dart` files totaling ~47,175 lines of code in the repository. The smithy goldens alone contain massive protocol test servers (5,500+ lines each).
- Files: `packages/smithy/goldens/lib/restJson1/lib/src/rest_json_protocol/rest_json_protocol_server.dart` (5,509 lines), `packages/smithy/goldens/lib2/restJson1/lib/src/rest_json_protocol/rest_json_protocol_server.dart` (5,507 lines), `packages/smithy/smithy_codegen/lib/src/aws/endpoints.g.dart` (17,273 lines)
- Cause: Code generation is necessary for AWS SDK compatibility, but the generated files are committed to the repository.
- Improvement path: Consider excluding goldens from default analysis. Evaluate whether generated SDK code can be published separately or generated on-demand.

**DataStore Observe Stream Filtering:**
- Problem: All model observation events flow through a single EventChannel and are filtered client-side by model type. Every `observe()` call filters the same global stream.
- Files: `packages/amplify_datastore/lib/src/method_channel_datastore.dart` (lines 246-273)
- Cause: Only one EventChannel is used for all model types due to MethodChannel architecture limitations.
- Improvement path: Migrate to Pigeon with per-model-type streaming, or implement server-side filtering in the native bridge.

## Fragile Areas

**WebSocket Bloc State Machine:**
- Files: `packages/api/amplify_api_dart/lib/src/graphql/web_socket/blocs/web_socket_bloc.dart`
- Why fragile: Complex state machine managing WebSocket connections with multiple stream controllers, timers, connectivity monitoring, and process lifecycle handling. Contains 10+ workarounds for DDC yield bugs. State transitions involve multiple async operations that must be coordinated.
- Safe modification: Any changes should be thoroughly tested on both web and native platforms. The existing test at `packages/api/amplify_api_dart/test/web_socket/web_socket_bloc_test.dart` has a skipped test for web.
- Test coverage: One test file with known web-specific skip.

**Sign-In State Machine:**
- Files: `packages/auth/amplify_auth_cognito_dart/lib/src/state/machines/sign_in_state_machine.dart` (1,428 lines)
- Why fragile: Handles multiple auth flows (SRP, custom, user-SRP-auth), MFA challenges, device tracking, and TOTP/SMS verification in a single state machine. Hides exceptions from other SDK modules to prevent namespace conflicts (lines 21-27).
- Safe modification: Changes to sign-in flows should use the dedicated test package at `packages/auth/amplify_auth_cognito_test/`. Test each auth flow path independently.
- Test coverage: Tests in separate package with 34 test files, but the state machine itself is complex enough that edge cases may be missed.

**Auth Plugin Implementation:**
- Files: `packages/auth/amplify_auth_cognito_dart/lib/src/auth_plugin_impl.dart` (1,171 lines)
- Why fragile: Single file implementing the full AuthPluginInterface with 40+ SDK imports. Uses implementation imports from `amplify_core` and `amplify_analytics_pinpoint_dart`. Tightly coupled to multiple internal state machines.
- Safe modification: Test via `packages/auth/amplify_auth_cognito_test/`. Changes to any dependent state machine can break this plugin.
- Test coverage: Tested through the separate test package but the file itself has only 2 test files in its own package.

**Authenticator Auth Category Interface:**
- Files: `packages/amplify_core/lib/src/category/amplify_auth_category.dart` (1,469 lines)
- Why fragile: Defines the entire public auth API surface. Every auth method delegates to the registered plugin. Contains extensive documentation with code examples that must stay in sync with actual behavior.
- Safe modification: Changes here affect all auth consumers. Coordinate with authenticator widget and auth plugin.
- Test coverage: 24 test files for all of `amplify_core`, but auth category specifically is tested mostly through integration.

## Scaling Limits

**Monorepo Package Count:**
- Current capacity: 30+ publishable packages with tight interdependencies.
- Limit: Coordinated publishing becomes increasingly complex. The `aft` (Amplify Flutter Tool) manages this but has known limitations (TODO for E2E Dart package runs).
- Scaling path: The `aft` tool at `packages/aft/` handles versioning and publishing. Consider reducing coupling between packages or consolidating related packages.

## Dependencies at Risk

**built_value / built_collection:**
- Risk: Heavily used for serialization across auth, analytics, and smithy packages. These are complex dependencies that add significant code generation overhead.
- Impact: If built_value stops being maintained or conflicts with Dart language evolution (e.g., records, sealed classes), migration would be extensive.
- Migration plan: Gradually migrate to Dart 3 features (records, sealed classes, pattern matching) where built_value is used for union types and serialization.

**Smithy Dart Serialization Workarounds:**
- Risk: Multiple serializers in the smithy package have workarounds for DDC crashes (BigInt, Int64, Timestamp serializers all have `TODO(dnys1): Remove when doing so wouldn't crash DDC`).
- Impact: If these workarounds are removed prematurely, web builds crash. If DDC is never fixed, this debt remains permanently.
- Files: `packages/smithy/smithy/lib/src/serialization/json/big_int_serializer.dart`, `packages/smithy/smithy/lib/src/serialization/json/int64_serializer.dart`, `packages/smithy/smithy/lib/src/serialization/json/timestamp_serializer.dart`
- Migration plan: Track Dart SDK issues and remove workarounds when DDC support improves.

## Missing Critical Features

**EC2 IMDS and ECS Container Credentials:**
- Problem: AWS credentials provider chain does not support EC2 Instance Metadata Service (IMDS) or ECS container credentials.
- Blocks: Server-side Dart applications running on EC2 or ECS cannot automatically discover their IAM credentials.
- Files: `packages/aws_common/lib/src/credentials/aws_credentials_provider_chain.dart` (line 55), `packages/aws_common/lib/src/credentials/aws_credentials_provider.dart` (lines 87-88)

**Assume Role Credentials:**
- Problem: Assume role credentials provider is not implemented, referenced in multiple TODOs.
- Blocks: Cannot use AWS STS AssumeRole for cross-account access or temporary elevated permissions.
- Files: `packages/aws_common/lib/src/config/aws_profile_file.dart` (line 116), `packages/aws_common/tool/generate_tests.dart` (line 213)

**amplify_db_common_dart Web Tests:**
- Problem: Database tests cannot run on web because sqlite3.wasm loading is not configured.
- Files: `packages/common/amplify_db_common_dart/test/main_test.dart` (line 4)

## Test Coverage Gaps

**amplify_flutter (core Flutter plugin):**
- What's not tested: Zero unit test files for the main Flutter plugin entry point.
- Files: `packages/amplify/amplify_flutter/lib/` (4 source files)
- Risk: Configuration, plugin registration, and the hybrid implementation at `packages/amplify/amplify_flutter/lib/src/hybrid_impl.dart` are untested.
- Priority: High - this is the main entry point for all Flutter consumers.

**amplify_auth_cognito (Flutter auth plugin):**
- What's not tested: Only 1 test file for 22 source files. Most testing is in the separate `amplify_auth_cognito_test` package (34 test files), but the Flutter-specific layer is sparsely tested.
- Files: `packages/auth/amplify_auth_cognito/lib/` (22 source files), `packages/auth/amplify_auth_cognito/test/` (1 test file)
- Risk: Flutter-specific auth behavior (platform channels, native plugin bridging) may have untested paths.
- Priority: Medium - core Dart logic is well-tested in the `_dart` variant, but Flutter integration layer is not.

**amplify_api (Flutter API plugin):**
- What's not tested: Only 1 test file for 25 source files. The connectivity_plus platform test is the only test.
- Files: `packages/api/amplify_api/lib/` (25 source files), `packages/api/amplify_api/test/` (1 test file)
- Risk: Flutter-specific API behavior including REST and GraphQL operations through the Flutter layer are undertested.
- Priority: Medium - Dart layer at `amplify_api_dart` has 12 test files, but Flutter-specific behavior is not covered.

**Web Platform Testing:**
- What's not tested: Multiple test suites are skipped on web (temporal types, storage downloads, WebSocket bloc, db_common). Web is a first-class platform but has significant test gaps.
- Files: Various `@OnPlatform` and `skip: kIsWeb` annotations across the codebase
- Risk: Web-specific regressions go undetected. The DDC yield workarounds suggest web behavior diverges from VM behavior.
- Priority: High - web is a supported platform with known behavior differences.

---

*Concerns audit: 2026-03-07*

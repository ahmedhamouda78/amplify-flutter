# Phase 3: Platform Bridges — iOS, Android, and Web - Context

**Gathered:** 2026-03-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement native WebAuthn ceremony bridges for iOS, Android, and Web so that passkey sign-in (getCredential) and registration (createCredential) work end-to-end. Each bridge implements the `WebAuthnCredentialPlatform` interface using platform-native APIs. A stub implementation covers unsupported platforms.

</domain>

<decisions>
## Implementation Decisions

### Pigeon Bridge Architecture
- Create a **new dedicated Pigeon file** (`webauthn_bridge.dart`) in `pigeons/` — do not extend the existing `NativeAuthBridge`
- All three methods (`createCredential`, `getCredential`, `isPasskeySupported`) are **async** via `@async` annotation
- Register the WebAuthn bridge in the **same plugin class** (`AmplifyAuthCognitoPlugin`) alongside existing OAuth bridge setup
- Use a **shared Darwin implementation file** for iOS (and macOS in Phase 4) — ASAuthorizationController works on both platforms

### Error Mapping Strategy
- **Coarse grouping** — map all platform errors to the 5 existing `PasskeyException` subtypes: `NotSupported`, `Cancelled`, `RegistrationFailed`, `AssertionFailed`, `RpMismatch`
- Preserve original platform error in `underlyingException` field for debugging
- Error mapping happens on the **Dart side** — native code throws raw `PlatformException` with error code/message, Dart layer maps to `PasskeyException` subtypes
- User cancellation is an **exception** (`PasskeyCancelledException`), not a null result — consistent with `UserCancelledException` pattern

### Web Bridge Location & Implementation
- Web bridge lives in the **pure Dart package** (`amplify_auth_cognito_dart`) with conditional import (`dart.library.js_interop`) — follows existing HostedUI web pattern
- Uses **`package:web`** for typed JS interop bindings to `navigator.credentials`
- Web bridge **converts JS ArrayBuffer/TypedArray responses to base64url strings** before returning JSON — maintains the JSON string contract across all platforms
- **Auto-registers via conditional import** — stub on non-web, real implementation on web, no explicit registration needed

### Platform Version & Capability Checks
- `isPasskeySupported()` uses **runtime API availability check** (not OS version check)
  - iOS: `@available(iOS 17.4, *)` check
  - Android: `CredentialManager` availability check
  - Web: Check `navigator.credentials` and `PublicKeyCredential` exist (API existence only, not `isUserVerifyingPlatformAuthenticatorAvailable`)
- On unsupported platforms: `isPasskeySupported()` returns `false`, `createCredential`/`getCredential` throw `PasskeyNotSupportedException`
- Stub implementation for unsupported platforms: `isPasskeySupported()` → `false`, create/get → throw `PasskeyNotSupportedException`

### Claude's Discretion
- Pigeon `@ConfigurePigeon` output paths and codec configuration
- Exact Swift/Kotlin implementation details for wrapping platform APIs
- JS interop extension types and helper utilities for web bridge
- Internal error code constants for Dart-side mapping
- Test structure and mock strategies

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WebAuthnCredentialPlatform` interface: `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart` — the contract all bridges implement
- `PasskeyException` hierarchy: `packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart` — 6 exception subtypes ready for use
- `PasskeyCreateOptions`/`PasskeyGetOptions` JSON types: `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/passkey_types.dart` — W3C-compliant serde
- Existing Pigeon definition: `packages/auth/amplify_auth_cognito/pigeons/native_auth_plugin.dart` — pattern to follow for new bridge
- HostedUI web platform: `packages/auth/amplify_auth_cognito_dart/lib/src/flows/hosted_ui/hosted_ui_platform_html.dart` — conditional import pattern for web

### Established Patterns
- Pigeon code generation: define in `pigeons/`, generates to `lib/src/` (Dart), `darwin/Classes/pigeons/` (Swift), `android/src/.../pigeons/` (Kotlin)
- Plugin registration: `NativeAuthBridgeSetup.setUp()` called in plugin's `onAttachedToEngine` (Android) / `register(with:)` (iOS)
- Dependency injection: bridge instances added via `stateMachine.addInstance<T>()`, retrieved via `get<T>()` in state machine handlers
- Conditional imports: `if (dart.library.js_interop)` for web, `if (dart.library.io)` for native, stub for fallback
- Web JS interop: `package:web` used for DOM access (window, document, navigator)

### Integration Points
- `auth_plugin_impl.dart`: Register WebAuthn Pigeon bridge alongside existing NativeAuthBridge during `addPlugin()`
- `sign_in_state_machine.dart`: Already calls `get<WebAuthnCredentialPlatform>()` to retrieve bridge (Phase 2)
- Pigeon-generated Dart code: imports into auth_plugin_impl for bridge setup
- Web conditional import: new file alongside existing `hosted_ui_platform_html.dart` pattern

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following the existing codebase patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-platform-bridges-ios-android-web*
*Context gathered: 2026-03-08*

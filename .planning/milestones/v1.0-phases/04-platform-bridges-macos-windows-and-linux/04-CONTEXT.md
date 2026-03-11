# Phase 4: Platform Bridges — macOS, Windows, and Linux - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend passkey support to macOS, Windows, and Linux platforms. macOS shares the existing Darwin/ASAuthorizationController implementation from Phase 3. Windows gets full FFI bindings to webauthn.dll (Windows Hello). Linux gets libfido2 FFI bindings for USB FIDO2 security keys with graceful fallback when the library is unavailable.

</domain>

<decisions>
## Implementation Decisions

### macOS Bridge Enablement
- macOS shares the **exact same Pigeon registration path** as iOS/Android — add `Platform.isMacOS` to the existing guard in `auth_plugin_impl.dart:58`
- Swift side is already complete (`WebAuthnBridgeImpl.swift` and `AmplifyAuthCognitoPlugin.swift` both handle `#if os(macOS)`)
- **Verify macOS podspec** deployment target is compatible with macOS 13.5+ for ASAuthorizationController; fix if needed
- No separate macOS-specific code needed on the Dart side

### Windows Bridge — Full FFI Implementation
- **Raw `dart:ffi` bindings to `webauthn.dll`** — call `WebAuthNAuthenticatorMakeCredential` and `WebAuthNGetAssertion` directly
- No external Dart packages — direct FFI to the Windows WebAuthn API
- **HWND acquisition:** Use `GetActiveWindow()` at ceremony time to get the Flutter app's window handle
- **Authenticator attachment:** Claude's discretion — respect whatever attachment preference Cognito sends in the options (platform-only vs cross-platform)
- `isPasskeySupported()` checks `WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable` or API DLL availability

### Linux Bridge — libfido2 FFI
- **USB FIDO2 security keys only** — no platform authenticator on Linux (accepted limitation)
- **Graceful fallback:** Dynamically load `libfido2.so` at runtime; if not found, `isPasskeySupported()` returns `false` and operations throw `PasskeyNotSupportedException`
- **User verification:** Respect Cognito's `userVerification` preference from the options JSON — pass through to libfido2
- No hard system dependency on libfido2

### Package Structure
- **Windows FFI code:** Inline in `amplify_auth_cognito/lib/src/windows/`
- **Linux FFI code:** Inline in `amplify_auth_cognito/lib/src/linux/`
- **Dependencies:** Both use `dart:ffi` + `package:ffi` (Arena, calloc, Utf8/Utf16 extensions)
- **Registration:** `Platform.isWindows` and `Platform.isLinux` guards in `addPlugin()` — register FFI-based `WebAuthnCredentialPlatform` directly, bypassing Pigeon

### FFI Adapter Pattern
- Claude's discretion — pick between direct `WebAuthnCredentialPlatform` implementation or shared adapter based on code simplicity

### Claude's Discretion
- Windows authenticator attachment policy (platform-only vs any, based on Cognito options)
- FFI adapter pattern (direct implementation vs shared adapter)
- Exact FFI struct layouts and memory management details
- libfido2 API surface selection (which functions to bind)
- Error code mapping from Windows HRESULT / libfido2 error codes to PasskeyException subtypes
- Test structure and mock strategies for FFI code

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WebAuthnCredentialPlatform` interface: `amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart` — contract all bridges implement
- `PigeonWebAuthnCredentialPlatform` adapter: `amplify_auth_cognito/lib/src/pigeon_webauthn_credential_platform.dart` — Pigeon-to-interface adapter with error mapping (reused for macOS)
- `WebAuthnErrorCodes`: string constants for error code mapping across all platforms
- `PasskeyException` hierarchy: 6 typed subtypes ready for use
- `WebAuthnBridgeImpl.swift`: Already handles both iOS and macOS via `#if os(iOS)` / `#elseif os(macOS)`
- `AmplifyAuthCognitoPlugin.swift`: Already registers WebAuthn bridge for both iOS and macOS
- Stub implementation: `webauthn_credential_platform_stub.dart` — fallback for truly unsupported platforms

### Established Patterns
- Pigeon bridge for iOS/Android/macOS: Pigeon-generated bindings with Dart adapter for error mapping
- Conditional imports: `if (dart.library.js_interop)` for web, `if (dart.library.io)` for native
- Plugin registration: `addPlugin()` in `auth_plugin_impl.dart` with platform guards
- JSON string boundary: all platform bridges accept/return JSON strings, serialization stays in Dart layer

### Integration Points
- `auth_plugin_impl.dart:58`: Guard needs `Platform.isMacOS` added; Windows/Linux guards added separately
- `stateMachine.addInstance<WebAuthnCredentialPlatform>()`: Same registration pattern for all platforms
- macOS podspec: Verify deployment target compatibility with macOS 13.5+
- `package:ffi` dependency: Add to `amplify_auth_cognito/pubspec.yaml` for Windows/Linux FFI

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

*Phase: 04-platform-bridges-macos-windows-and-linux*
*Context gathered: 2026-03-09*

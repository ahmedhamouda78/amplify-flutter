# Phase 4: Platform Bridges -- macOS, Windows, and Linux - Research

**Researched:** 2026-03-09
**Domain:** Platform-specific WebAuthn FFI bindings (macOS Darwin, Windows Hello, Linux libfido2)
**Confidence:** HIGH (macOS), MEDIUM (Windows), MEDIUM (Linux)

## Summary

This phase extends passkey support to the three remaining desktop platforms. macOS is the simplest -- the Darwin implementation from Phase 3 already compiles for macOS via `#if os(macOS)` guards in Swift, requiring only a one-line Dart guard addition and a podspec deployment target fix. Windows requires substantial FFI work to call `webauthn.dll` (the Windows Hello FIDO2 API), but a critical discovery simplifies this: the Windows WebAuthn API (version 4+) supports JSON-in/JSON-out via `pbPublicKeyCredentialCreationOptionsJSON`/`pbRegistrationResponseJSON` fields, allowing direct pass-through of the project's existing JSON string boundary without manually constructing every C struct. Linux uses `libfido2` FFI for USB FIDO2 security keys with dynamic loading and graceful fallback.

The project already has established FFI patterns in `amplify_secure_storage_dart` using `dart:ffi` + `package:ffi` (Arena, calloc, Utf16/Utf8 extensions), and `package:win32` for Windows APIs. The Windows bridge uses raw `dart:ffi` to `webauthn.dll` per user decision (no `package:win32` dependency for this specific API). Linux uses `DynamicLibrary.open('libfido2.so')` with the same graceful-failure pattern as the secure storage package.

**Primary recommendation:** Implement macOS first (trivial enablement), then Windows FFI bridge using the JSON pass-through approach (API version 7+), then Linux libfido2 FFI with graceful fallback.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- macOS shares the exact same Pigeon registration path as iOS/Android -- add `Platform.isMacOS` to the existing guard in `auth_plugin_impl.dart:58`
- Swift side is already complete (`WebAuthnBridgeImpl.swift` and `AmplifyAuthCognitoPlugin.swift` both handle `#if os(macOS)`)
- Verify macOS podspec deployment target is compatible with macOS 13.5+ for ASAuthorizationController; fix if needed
- No separate macOS-specific code needed on the Dart side
- Raw `dart:ffi` bindings to `webauthn.dll` -- call `WebAuthNAuthenticatorMakeCredential` and `WebAuthNGetAssertion` directly
- No external Dart packages for Windows -- direct FFI to the Windows WebAuthn API
- HWND acquisition: Use `GetActiveWindow()` at ceremony time to get the Flutter app's window handle
- `isPasskeySupported()` checks `WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable` or API DLL availability
- Linux: USB FIDO2 security keys only -- no platform authenticator on Linux (accepted limitation)
- Graceful fallback: Dynamically load `libfido2.so` at runtime; if not found, `isPasskeySupported()` returns `false` and operations throw `PasskeyNotSupportedException`
- User verification: Respect Cognito's `userVerification` preference from the options JSON -- pass through to libfido2
- No hard system dependency on libfido2
- Windows FFI code: Inline in `amplify_auth_cognito/lib/src/windows/`
- Linux FFI code: Inline in `amplify_auth_cognito/lib/src/linux/`
- Dependencies: Both use `dart:ffi` + `package:ffi` (Arena, calloc, Utf8/Utf16 extensions)
- Registration: `Platform.isWindows` and `Platform.isLinux` guards in `addPlugin()` -- register FFI-based `WebAuthnCredentialPlatform` directly, bypassing Pigeon

### Claude's Discretion
- Windows authenticator attachment policy (platform-only vs any, based on Cognito options)
- FFI adapter pattern (direct implementation vs shared adapter)
- Exact FFI struct layouts and memory management details
- libfido2 API surface selection (which functions to bind)
- Error code mapping from Windows HRESULT / libfido2 error codes to PasskeyException subtypes
- Test structure and mock strategies for FFI code

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-03 | macOS platform bridge shares iOS/Darwin ASAuthorizationController implementation (macOS 13.5+) | Swift code already handles macOS via `#if os(macOS)`. Requires: add `Platform.isMacOS` guard, fix podspec deployment target from 10.15 to 13.5 |
| PLAT-05 | Windows platform bridge wraps Windows Hello FIDO2 APIs via FFI bindings | Windows WebAuthn API researched: `WebAuthNAuthenticatorMakeCredential` and `WebAuthNGetAssertion` in `webauthn.dll`. JSON pass-through available via version 7+ API fields |
| PLAT-06 | Linux platform bridge provides best-effort passkey support via libfido2 FFI or returns `isPasskeySupported() = false` | libfido2 API researched: `fido_dev_make_cred` and `fido_dev_get_assert`. Dynamic loading with graceful fallback pattern |
| PLAT-08 | Platform bridges map platform-specific errors to typed Amplify AuthException subtypes | Windows HRESULT error codes and libfido2 error codes documented. Map to existing PasskeyException subtypes via WebAuthnErrorCodes constants |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dart:ffi` | (built-in) | Foreign function interface for calling C APIs | Required for Windows webauthn.dll and Linux libfido2 |
| `package:ffi` | ^2.0.2 | Arena allocator, calloc, Utf8/Utf16 extensions | Already used by project (amplify_secure_storage_dart) |
| `webauthn.dll` | API v4+ | Windows Hello FIDO2 API | System DLL, ships with Windows 10 1903+ |
| `libfido2.so` | 1.x | FIDO2 library for USB security keys | Standard FIDO2 library on Linux |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dart:convert` | (built-in) | JSON encode/decode | Parsing options JSON, building response JSON |
| `dart:io` | (built-in) | Platform detection | `Platform.isWindows`, `Platform.isLinux`, `Platform.isMacOS` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw `dart:ffi` to webauthn.dll | `package:win32` | win32 does NOT include webauthn.h bindings; raw FFI is the only option |
| Raw `dart:ffi` to libfido2 | `package:fido2` | No mature Dart package exists for libfido2; raw FFI is necessary |

**Installation:**
```bash
# Add package:ffi to amplify_auth_cognito/pubspec.yaml
# No native dependencies to install -- webauthn.dll is system-provided
# libfido2 is optional runtime dependency on Linux
```

## Architecture Patterns

### Recommended Project Structure
```
amplify_auth_cognito/lib/src/
  windows/
    webauthn_bindings.dart       # FFI function lookups and struct definitions
    windows_webauthn_platform.dart  # WebAuthnCredentialPlatform implementation
  linux/
    libfido2_bindings.dart       # FFI function lookups and struct definitions
    linux_webauthn_platform.dart # WebAuthnCredentialPlatform implementation
  pigeon_webauthn_credential_platform.dart  # Existing (iOS/Android/macOS via Pigeon)
```

### Pattern 1: Direct WebAuthnCredentialPlatform Implementation (Recommended)
**What:** Each platform bridge directly implements `WebAuthnCredentialPlatform` without a shared adapter layer.
**When to use:** When each platform has fundamentally different FFI patterns (Pigeon vs raw FFI).
**Example:**
```dart
// Source: Project pattern from WebAuthnCredentialPlatform interface
class WindowsWebAuthnPlatform implements WebAuthnCredentialPlatform {
  @override
  Future<String> createCredential(String optionsJson) async {
    return using((Arena arena) {
      // Allocate structs, call WebAuthNAuthenticatorMakeCredential
      // Return JSON response
    });
  }
}
```

### Pattern 2: JSON Pass-Through for Windows (Critical Simplification)
**What:** The Windows WebAuthn API (version 7+) supports passing raw JSON options and returns JSON responses directly, avoiding manual C struct population for every field.
**When to use:** When the API version supports `pbPublicKeyCredentialCreationOptionsJSON` fields.
**How it works:**
- For MakeCredential: Set `cbPublicKeyCredentialCreationOptionsJSON`/`pbPublicKeyCredentialCreationOptionsJSON` in options, read `cbRegistrationResponseJSON`/`pbRegistrationResponseJSON` from result
- For GetAssertion: Set `cbPublicKeyCredentialRequestOptionsJSON`/`pbPublicKeyCredentialRequestOptionsJSON` in options, read `cbAuthenticationResponseJSON`/`pbAuthenticationResponseJSON` from result
- Still need minimal struct population (HWND, client data, RP/user info for older fallback), but the JSON fields handle the complex parts

**Fallback approach:** If API version is too old for JSON fields, populate all C structs manually from parsed JSON. This is the complex path and should be version-gated.

### Pattern 3: Dynamic Library Loading with Graceful Fallback (Linux)
**What:** Try to load `libfido2.so` at runtime; if unavailable, all operations fail gracefully.
**When to use:** When the native library is optional.
**Example:**
```dart
// Source: Project pattern from amplify_secure_storage_dart/dynamic_library_utils.dart
class LinuxWebAuthnPlatform implements WebAuthnCredentialPlatform {
  late final DynamicLibrary? _lib;

  LinuxWebAuthnPlatform() {
    try {
      _lib = DynamicLibrary.open('libfido2.so');
    } on ArgumentError {
      _lib = null;
    }
  }

  @override
  Future<bool> isPasskeySupported() async => _lib != null;
}
```

### Pattern 4: Platform Registration in addPlugin()
**What:** Register the appropriate WebAuthnCredentialPlatform based on platform detection.
**When to use:** For the auth plugin initialization.
**Example:**
```dart
// In auth_plugin_impl.dart addPlugin():
if (zIsWeb || !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
  // For Windows/Linux, register FFI-based platforms separately below
  if (Platform.isWindows) {
    stateMachine.addInstance<WebAuthnCredentialPlatform>(
      WindowsWebAuthnPlatform(),
    );
  } else if (Platform.isLinux) {
    stateMachine.addInstance<WebAuthnCredentialPlatform>(
      LinuxWebAuthnPlatform(),
    );
  }
  return;
}
// iOS/Android/macOS use Pigeon bridge (existing code)
```

### Anti-Patterns to Avoid
- **Populating all Windows structs manually when JSON pass-through is available:** The WebAuthn API has 20+ structs with complex nested relationships. Use the JSON fields when API version supports them.
- **Hard-linking libfido2 on Linux:** Must use DynamicLibrary.open() for runtime loading, never compile-time linking.
- **Sharing one FFI file between Windows and Linux:** These are completely different C APIs (webauthn.h vs libfido2); keep them separate.
- **Blocking the main isolate with synchronous FFI calls:** The Windows `WebAuthNAuthenticatorMakeCredential` call is blocking (waits for user interaction). Wrap in `Isolate.run()` or use the Arena pattern with async wrappers.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Base64URL encoding/decoding | Custom codec | `dart:convert` base64 + manual URL-safe transform | Already established in the project's WebAuthn serialization layer |
| CBOR parsing for attestation objects | Custom CBOR parser | Windows API provides attestation object as raw bytes; pass through | The Cognito server handles CBOR; client just passes bytes |
| Client data JSON construction | Manual string building | Windows API's `WEBAUTHN_CLIENT_DATA` struct handles this internally | Windows builds clientDataJSON from the struct fields |
| Credential response JSON (Windows) | Manual JSON assembly from struct fields | `pbRegistrationResponseJSON` / `pbAuthenticationResponseJSON` API fields | Windows API version 4+ provides pre-built JSON responses |

**Key insight:** The Windows WebAuthn API does the heavy lifting of constructing clientDataJSON and attestation objects. The Linux libfido2 API requires more manual assembly of the response JSON from individual getter functions, but the raw bytes can be base64url-encoded and assembled into the standard response format.

## Common Pitfalls

### Pitfall 1: macOS Podspec Deployment Target Too Low
**What goes wrong:** The podspec sets `s.osx.deployment_target = '10.15'` but ASAuthorizationController for passkeys requires macOS 13.5+.
**Why it happens:** The podspec was set for the original auth plugin features (hosted UI), not WebAuthn.
**How to avoid:** Update deployment target to `'13.5'` in the podspec. The Swift code already has `#available(macOS 13.5, *)` guards so older macOS versions return `isPasskeySupported() = false`.
**Warning signs:** Build errors or runtime crashes on macOS when calling ASAuthorization APIs.
**IMPORTANT:** Raising the deployment target to 13.5 means the entire plugin requires macOS 13.5+. The existing `#available` runtime checks in Swift handle graceful degradation, but CocoaPods will refuse to install on projects targeting older macOS. Evaluate whether this is acceptable or if 13.0 is a better minimum (the `#available` checks already handle the 13.0-13.4 gap).

### Pitfall 2: Windows WebAuthn API Version Mismatch
**What goes wrong:** The JSON pass-through fields (`pbPublicKeyCredentialCreationOptionsJSON`) were added in later API versions. Older Windows 10 builds may not support them.
**Why it happens:** The struct layout grows with each version. Accessing fields beyond the allocated version size causes memory corruption.
**How to avoid:** Call `WebAuthNGetApiVersionNumber()` first. If version >= 4 (API_VERSION_4), use JSON pass-through. If older, fall back to manual struct population or return `isPasskeySupported() = false`.
**Warning signs:** Access violations, garbage data, or missing function symbols on older Windows builds.

### Pitfall 3: Windows HWND Acquisition Timing
**What goes wrong:** `GetActiveWindow()` returns NULL if no window is focused.
**Why it happens:** The call happens before the Flutter window is visible, or another window has focus.
**How to avoid:** Call `GetActiveWindow()` or `GetForegroundWindow()` at ceremony time (not at init), with a fallback to `FindWindow()`. If NULL, throw a descriptive error.
**Warning signs:** HRESULT error from WebAuthn API indicating invalid window handle.

### Pitfall 4: Memory Leaks in Windows FFI
**What goes wrong:** Native memory from `WebAuthNAuthenticatorMakeCredential` result is never freed.
**Why it happens:** The API allocates `WEBAUTHN_CREDENTIAL_ATTESTATION` and `WEBAUTHN_ASSERTION` structs that must be freed with `WebAuthNFreeCredentialAttestation` and `WebAuthNFreeAssertion`.
**How to avoid:** Always call the corresponding Free function in a finally block after reading the result data.
**Warning signs:** Gradual memory increase during repeated passkey operations.

### Pitfall 5: libfido2 Device Discovery Complexity
**What goes wrong:** Attempting to open a specific device path that doesn't exist, or finding no devices.
**Why it happens:** Linux FIDO2 devices appear at different paths (`/dev/hidraw*`), and require udev rules for non-root access.
**How to avoid:** Use `fido_dev_info_manifest()` to discover available devices. If no devices found, throw `PasskeyNotSupportedException`. Document the udev rules requirement.
**Warning signs:** Permission denied errors, or "no device found" on systems that have FIDO2 keys plugged in.

### Pitfall 6: libfido2 Requires Manual Response JSON Assembly
**What goes wrong:** Unlike Windows (which provides JSON response fields), libfido2 returns raw byte arrays for each field separately.
**Why it happens:** libfido2 is a lower-level library; it doesn't produce W3C WebAuthn JSON.
**How to avoid:** Build the response JSON manually from individual libfido2 getter functions, base64url-encoding each byte array. Follow the same JSON structure as the iOS/web bridges produce.
**Warning signs:** Cognito rejecting the credential response due to missing or malformed fields.

### Pitfall 7: Blocking FFI Call on Main Isolate (Windows)
**What goes wrong:** `WebAuthNAuthenticatorMakeCredential` blocks until user completes the Windows Hello dialog. This freezes the Flutter UI.
**Why it happens:** Dart FFI calls are synchronous and block the calling isolate.
**How to avoid:** The Windows Hello dialog is system-modal and blocks the thread regardless. Since Flutter on Windows runs on a single thread, the blocking is acceptable -- the system UI is displayed and the Flutter UI is not interactive during it. However, if UI responsiveness is needed during the ceremony, use `Isolate.run()`.
**Warning signs:** Flutter UI becomes unresponsive during passkey ceremony (expected behavior with Windows Hello modal dialog).

## Code Examples

### macOS Enablement (auth_plugin_impl.dart line 58)
```dart
// BEFORE:
if (zIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
  return;
}

// AFTER (add Platform.isMacOS to the native plugin guard):
if (zIsWeb || !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
  // Handle Windows/Linux separately
  if (!zIsWeb && Platform.isWindows) {
    stateMachine.addInstance<WebAuthnCredentialPlatform>(
      WindowsWebAuthnPlatform(),
    );
    return;
  }
  if (!zIsWeb && Platform.isLinux) {
    stateMachine.addInstance<WebAuthnCredentialPlatform>(
      LinuxWebAuthnPlatform(),
    );
    return;
  }
  return;
}
```

### Windows FFI Bindings Pattern
```dart
// Source: Windows WebAuthn API docs (learn.microsoft.com)
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Load webauthn.dll
final _webauthn = DynamicLibrary.open('webauthn.dll');

// Function typedefs
typedef WebAuthNGetApiVersionNumberNative = Uint32 Function();
typedef WebAuthNGetApiVersionNumberDart = int Function();

typedef WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableNative
    = Int32 Function(Pointer<Int32> pbAvailable);
typedef WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableDart
    = int Function(Pointer<Int32> pbAvailable);

typedef WebAuthNAuthenticatorMakeCredentialNative = Int32 Function(
  IntPtr hWnd,  // HWND
  Pointer rpInfo,
  Pointer userInfo,
  Pointer pubKeyCredParams,
  Pointer clientData,
  Pointer options,
  Pointer<Pointer> ppCredentialAttestation,
);

typedef WebAuthNFreeCredentialAttestationNative = Void Function(
  Pointer pCredentialAttestation,
);

// Lookup functions
final getApiVersionNumber = _webauthn.lookupFunction<
    WebAuthNGetApiVersionNumberNative,
    WebAuthNGetApiVersionNumberDart>('WebAuthNGetApiVersionNumber');

final isUserVerifyingPlatformAuthenticatorAvailable = _webauthn.lookupFunction<
    WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableNative,
    WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableDart>(
    'WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable');
```

### Windows Struct Definitions (Key Structs)
```dart
// Source: webauthn.h via Microsoft Learn docs
// WEBAUTHN_RP_ENTITY_INFORMATION
final class WebAuthnRpEntityInformation extends Struct {
  @Uint32()
  external int dwVersion;  // = 1
  external Pointer<Utf16> pwszId;
  external Pointer<Utf16> pwszName;
  external Pointer<Utf16> pwszIcon;
}

// WEBAUTHN_USER_ENTITY_INFORMATION
final class WebAuthnUserEntityInformation extends Struct {
  @Uint32()
  external int dwVersion;  // = 1
  @Uint32()
  external int cbId;
  external Pointer<Uint8> pbId;
  external Pointer<Utf16> pwszName;
  external Pointer<Utf16> pwszIcon;
  external Pointer<Utf16> pwszDisplayName;
}

// WEBAUTHN_CLIENT_DATA
final class WebAuthnClientData extends Struct {
  @Uint32()
  external int dwVersion;  // = 1
  @Uint32()
  external int cbClientDataJSON;
  external Pointer<Uint8> pbClientDataJSON;
  external Pointer<Utf16> pwszHashAlgId;  // "SHA-256"
}

// WEBAUTHN_COSE_CREDENTIAL_PARAMETER
final class WebAuthnCoseCredentialParameter extends Struct {
  @Uint32()
  external int dwVersion;  // = 1
  external Pointer<Utf16> pwszCredentialType;  // "public-key"
  @Int32()
  external int lAlg;  // -7 for ES256
}
```

### Windows HRESULT Error Mapping
```dart
// Source: Windows error codes + project WebAuthnErrorCodes pattern
// Key HRESULT values from webauthn.dll:
// NTE_USER_CANCELLED    = 0x80090036 -- user cancelled
// NTE_NOT_FOUND         = 0x80090011 -- no matching credential
// NTE_TOKEN_KEYSET_STORAGE_FULL = 0x80090023 -- storage full
// NTE_INVALID_PARAMETER = 0x80090027 -- bad input

String _mapHResultToErrorCode(int hr) {
  switch (hr) {
    case 0x80090036: // NTE_USER_CANCELLED
      return WebAuthnErrorCodes.cancelled;
    case 0x80090011: // NTE_NOT_FOUND
      return WebAuthnErrorCodes.assertionFailed;
    default:
      return _isRegistration
          ? WebAuthnErrorCodes.registrationFailed
          : WebAuthnErrorCodes.assertionFailed;
  }
}
```

### Linux libfido2 FFI Bindings Pattern
```dart
// Source: libfido2 man pages (developers.yubico.com)
import 'dart:ffi';

typedef FidoCredNewNative = Pointer Function();
typedef FidoCredNewDart = Pointer Function();

typedef FidoDevMakeCredNative = Int32 Function(
  Pointer dev, Pointer cred, Pointer<Utf8> pin);
typedef FidoDevMakeCredDart = int Function(
  Pointer dev, Pointer cred, Pointer<Utf8> pin);

typedef FidoDevInfoManifestNative = Int32 Function(
  Pointer devInfoList, IntPtr maxEntries, Pointer<IntPtr> actualCount);

class LibFido2Bindings {
  final DynamicLibrary _lib;

  late final fidoCredNew = _lib.lookupFunction<FidoCredNewNative, FidoCredNewDart>('fido_cred_new');
  late final fidoDevMakeCred = _lib.lookupFunction<FidoDevMakeCredNative, FidoDevMakeCredDart>('fido_dev_make_cred');
  // ... additional bindings

  LibFido2Bindings(this._lib);
}
```

### Linux Graceful Fallback Pattern
```dart
// Source: Project pattern from amplify_secure_storage_dart/dynamic_library_utils.dart
class LinuxWebAuthnPlatform implements WebAuthnCredentialPlatform {
  final LibFido2Bindings? _bindings;

  LinuxWebAuthnPlatform() : _bindings = _tryLoadLibFido2();

  static LibFido2Bindings? _tryLoadLibFido2() {
    try {
      final lib = DynamicLibrary.open('libfido2.so');
      return LibFido2Bindings(lib);
    } on ArgumentError {
      return null;
    }
  }

  @override
  Future<bool> isPasskeySupported() async => _bindings != null;

  @override
  Future<String> createCredential(String optionsJson) async {
    if (_bindings == null) {
      throw const PasskeyNotSupportedException(
        'libfido2 is not available. Install libfido2-dev for passkey support.',
      );
    }
    // ... FFI calls
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual struct population for Windows WebAuthn | JSON pass-through via `pbPublicKeyCredentialCreationOptionsJSON` fields | WebAuthn API v4 (Windows 10 2004+) | Massively simplifies Windows FFI -- pass JSON directly instead of populating 10+ nested C structs |
| `package:win32` for all Windows APIs | Raw `dart:ffi` for APIs not in win32 | Ongoing | webauthn.h bindings not available in win32 package |
| macOS deployment target 10.15 | Need macOS 13.5+ for passkeys | macOS Ventura 13.5 (2023) | Podspec deployment target must be updated |

**Deprecated/outdated:**
- `WebAuthNAuthenticatorMakeCredential` options v1-v3: Lack JSON pass-through fields. Use v4+ (API version 4).
- `WEBAUTHN_CREDENTIALS` (CredentialList field): Superseded by `PWEBAUTHN_CREDENTIAL_LIST` (pExcludeCredentialList/pAllowCredentialList) in later versions.

## Validation Architecture

### Test Strategy Overview

Phase 4's platform bridges involve native FFI code that inherently cannot be unit-tested in a platform-independent way. The strategy is layered:

1. **Pure Dart logic** (JSON parsing, error mapping, response assembly) -- unit testable anywhere
2. **FFI bindings correctness** -- requires platform-specific integration tests (`@TestOn('windows')`, `@TestOn('linux')`)
3. **End-to-end WebAuthn ceremony** -- manual-only (requires hardware authenticator or platform biometrics)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `package:test` (Dart) / `flutter_test` (Flutter) |
| Config file | None specific -- uses standard `dart test` runner |
| Quick run command | `dart test packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` |
| Full suite command | `dart test packages/auth/amplify_auth_cognito_test/test/` |

### What Can Be Unit Tested (Cross-Platform)

These tests run on ANY platform (macOS CI, Linux CI, etc.) because they mock the `WebAuthnCredentialPlatform` interface:

| Test Area | Test Type | Where | What to Assert |
|-----------|-----------|-------|----------------|
| Platform registration logic | Unit | `amplify_auth_cognito_test` | `addPlugin()` registers correct platform class based on `Platform.is*` |
| Windows HRESULT-to-PasskeyException mapping | Unit | `amplify_auth_cognito_test` | Each HRESULT code maps to correct `WebAuthnErrorCodes` constant |
| Linux libfido2 error-to-PasskeyException mapping | Unit | `amplify_auth_cognito_test` | Each libfido2 error code maps to correct exception type |
| `isPasskeySupported()` with null bindings (Linux) | Unit | `amplify_auth_cognito_test` | Returns `false` when `_bindings` is null |
| Linux response JSON assembly | Unit | `amplify_auth_cognito_test` | Given raw byte arrays, produces valid W3C WebAuthn JSON |
| Windows JSON pass-through response parsing | Unit | `amplify_auth_cognito_test` | Given API response JSON string, returns it correctly |
| Graceful exception propagation | Unit | Already exists | `sign_in_webauthn_test.dart` covers cancellation, missing platform, missing options |

### Mock Strategies for FFI Code

**Primary strategy: Mock at the `WebAuthnCredentialPlatform` interface boundary.**

The project already has `MockWebAuthnCredentialPlatform` in `sign_in_webauthn_test.dart` (lines 21-43). This mock takes callback functions for each operation and is used to test the full sign-in state machine flow without any platform code. This is the correct abstraction level for most tests.

```dart
// EXISTING mock -- reuse for Phase 4 tests
class MockWebAuthnCredentialPlatform implements WebAuthnCredentialPlatform {
  MockWebAuthnCredentialPlatform({
    this.onGetCredential,
    this.onCreateCredential,
    this.onIsPasskeySupported,
  });
  // ...
}
```

**Secondary strategy: Inject the DynamicLibrary / bindings class.**

For testing the bridge implementations themselves (not the state machine), make the native bindings injectable:

```dart
// Make bindings injectable for testing
class WindowsWebAuthnPlatform implements WebAuthnCredentialPlatform {
  final WebAuthnBindings _bindings;

  WindowsWebAuthnPlatform([WebAuthnBindings? bindings])
      : _bindings = bindings ?? WebAuthnBindings();
  // ...
}

// In tests, provide a mock bindings class
class MockWebAuthnBindings implements WebAuthnBindings {
  @override
  int getApiVersionNumber() => 7;  // simulate API version
  @override
  int isUserVerifyingPlatformAuthenticatorAvailable(Pointer<Int32> p) {
    p.value = 1;
    return 0; // S_OK
  }
  // ...
}
```

**Tertiary strategy: Extract pure functions from FFI bridge code.**

Keep JSON parsing, error mapping, and response assembly as standalone pure functions that can be unit tested without any FFI involvement:

```dart
// Pure function -- testable anywhere
String mapHResultToErrorCode(int hr, {required bool isRegistration}) { ... }

// Pure function -- testable anywhere
Map<String, dynamic> assembleLibFido2ResponseJson({
  required List<int> credentialId,
  required List<int> clientDataJSON,
  required List<int> authenticatorData,
  required List<int> signature,
  List<int>? userHandle,
}) { ... }
```

### Platform-Specific Integration Tests

These require running ON the target platform:

| Platform | Test Type | Constraint | What to Test |
|----------|-----------|------------|-------------|
| Windows | Integration (`@TestOn('windows')`) | Needs Windows CI runner | DLL loading, `getApiVersionNumber()`, `isUserVerifyingPlatformAuthenticatorAvailable()` (no user interaction) |
| Linux | Integration (`@TestOn('linux')`) | Needs Linux CI runner + libfido2-dev | Library loading success/failure, `fido_init()` call succeeds |
| macOS | Integration (`@TestOn('mac-os')`) | Needs macOS CI runner | Podspec builds, `isPasskeySupported()` returns bool without crash |

**Pattern from project:** The `amplify_secure_storage_test` package uses `@TestOn('windows')` and `@TestOn('linux')` annotations for platform-specific tests. Follow the same pattern.

### Platform Availability Checks (Testable Without Hardware)

These operations do NOT require user interaction or a physical authenticator, so they can be tested in CI:

| Check | Platform | API Call | CI-Testable? |
|-------|----------|----------|-------------|
| DLL loads successfully | Windows | `DynamicLibrary.open('webauthn.dll')` | Yes (any Windows runner) |
| API version query | Windows | `WebAuthNGetApiVersionNumber()` | Yes (returns int, no UI) |
| Platform authenticator check | Windows | `WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable()` | Yes (returns bool, no UI) |
| libfido2 loads | Linux | `DynamicLibrary.open('libfido2.so')` | Yes (if libfido2-dev installed) |
| libfido2 graceful failure | Linux | `DynamicLibrary.open('libfido2.so')` throws | Yes (if libfido2-dev NOT installed) |
| `isPasskeySupported()` | All | Interface method | Yes (no UI, no hardware) |

### Manual-Only Tests (Require Hardware/Biometrics)

| Test | Platform | Why Manual |
|------|----------|-----------|
| Full MakeCredential ceremony | Windows | Requires Windows Hello biometric prompt |
| Full GetAssertion ceremony | Windows | Requires Windows Hello biometric prompt |
| Full MakeCredential ceremony | Linux | Requires physical FIDO2 USB key |
| Full GetAssertion ceremony | Linux | Requires physical FIDO2 USB key |
| Full passkey create/sign-in | macOS | Requires Touch ID or password on macOS 13.5+ |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAT-03 | macOS bridge enabled via Pigeon (same as iOS) | Unit (mock interface) + manual (macOS build) | `dart test packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` | Partially (existing WebAuthn tests cover interface-level; macOS build verification is manual) |
| PLAT-05 | Windows FFI bridge creates/gets credentials | Unit (error mapping, JSON parsing) + Integration (`@TestOn('windows')` for DLL loading) | `dart test test/windows_webauthn_test.dart` | No -- Wave 0 |
| PLAT-06 | Linux FFI bridge with graceful fallback | Unit (fallback logic, error mapping) + Integration (`@TestOn('linux')` for lib loading) | `dart test test/linux_webauthn_test.dart` | No -- Wave 0 |
| PLAT-08 | Error mapping from HRESULT / libfido2 to PasskeyException | Unit | `dart test test/webauthn_error_mapping_test.dart` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `dart test packages/auth/amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` (existing tests still pass)
- **Per wave merge:** `dart test packages/auth/amplify_auth_cognito_test/test/` (full auth test suite)
- **Phase gate:** Full suite green + manual verification on at least Windows (most impactful new bridge)

### Wave 0 Gaps
- [ ] `packages/auth/amplify_auth_cognito_test/test/platform/windows_webauthn_test.dart` -- unit tests for HRESULT error mapping, JSON pass-through parsing, API version gating logic
- [ ] `packages/auth/amplify_auth_cognito_test/test/platform/linux_webauthn_test.dart` -- unit tests for libfido2 error mapping, graceful fallback, response JSON assembly
- [ ] `packages/auth/amplify_auth_cognito_test/test/platform/webauthn_error_mapping_test.dart` -- shared error mapping tests (HRESULT codes, libfido2 error codes to PasskeyException subtypes)
- [ ] `packages/auth/amplify_auth_cognito/test/platform_registration_test.dart` -- verifies correct WebAuthnCredentialPlatform is registered per platform guard in addPlugin()

### How to Verify Correctness Without Physical Devices on CI

1. **Interface-level mocking (highest value, existing pattern):** The `MockWebAuthnCredentialPlatform` already proves the state machine handles WebAuthn correctly regardless of platform. Phase 4 bridges are simply new implementations of this same interface. If the mock-based tests pass, and the bridges produce the same JSON format, the integration works.

2. **Pure function extraction:** Extract all non-FFI logic (error mapping, JSON assembly, version gating) into pure Dart functions. Test these exhaustively on any platform.

3. **DLL/SO loading smoke tests:** On platform-specific CI runners, verify that `DynamicLibrary.open()` succeeds and basic non-interactive functions work (version check, authenticator availability check). These prove the FFI bindings are correctly defined without needing user interaction.

4. **Contract testing:** Define the exact JSON input/output contract (from `sign_in_webauthn_test.dart`'s `testCredentialRequestOptions` and `testCredentialResponse` constants). New bridges must produce JSON that matches this contract. Test the JSON assembly in isolation.

5. **Compilation verification:** Ensure the platform-specific code compiles on its target platform. For Windows, this means `dart compile exe` or `flutter build windows` on a Windows runner. For Linux, `flutter build linux`.

## Open Questions

1. **Windows API Version for JSON Pass-Through**
   - What we know: The JSON fields appear in `MAKE_CREDENTIAL_OPTIONS_VERSION_5` and `GET_ASSERTION_OPTIONS_VERSION_6`. The `CREDENTIAL_ATTESTATION_VERSION_4` has `pbRegistrationResponseJSON`. The `ASSERTION_VERSION_3` has `pbAuthenticationResponseJSON`.
   - What's unclear: The exact minimum Windows build (Windows 10 version) that supports these fields. API version 4 was Windows 10 2004 but the JSON fields may require newer versions.
   - Recommendation: Check `WebAuthNGetApiVersionNumber()` at runtime. If < 4, return `isPasskeySupported() = false` (very old Windows). For JSON fields, check if the struct version supports them. Fall back to manual struct population if needed, but this is a rare edge case on modern Windows.

2. **libfido2 Client Data Handling**
   - What we know: libfido2 expects client data hash, not raw client data JSON. The Windows API builds clientDataJSON internally.
   - What's unclear: Whether the project needs to construct clientDataJSON on the Dart side for libfido2 and hash it, or if the raw options JSON from Cognito already contains the necessary data.
   - Recommendation: Construct clientDataJSON in Dart (it's a simple JSON with type, challenge, origin, crossOrigin fields), SHA-256 hash it, and pass the hash to `fido_cred_set_clientdata_hash()`. Include the raw clientDataJSON in the response since Cognito needs it.

3. **libfido2 Device Selection UX**
   - What we know: `fido_dev_info_manifest()` lists available FIDO2 devices. Need to pick one for the ceremony.
   - What's unclear: How to handle multiple connected FIDO2 keys, or prompt user to insert a key.
   - Recommendation: Use the first available device. If no device is found, throw `PasskeyNotSupportedException`. Multi-device selection is out of scope for best-effort Linux support.

## Sources

### Primary (HIGH confidence)
- Microsoft Learn: webauthn.h API reference -- struct definitions, function signatures, constants
  - https://learn.microsoft.com/en-us/windows/win32/api/webauthn/
  - https://learn.microsoft.com/en-us/windows/win32/webauthn/webauthn-constants
- Yubico libfido2 man pages -- credential and assertion API functions
  - https://developers.yubico.com/libfido2/Manuals/
- Project codebase: `amplify_auth_cognito_test/test/state/sign_in_webauthn_test.dart` -- verified existing mock patterns and test infrastructure

### Secondary (MEDIUM confidence)
- Project codebase: `amplify_secure_storage_dart/lib/src/ffi/` -- established FFI patterns for Windows/Linux
- Project codebase: `amplify_auth_cognito/darwin/Classes/WebAuthnBridgeImpl.swift` -- verified macOS support already exists
- Project codebase: `amplify_auth_cognito/darwin/amplify_auth_cognito.podspec` -- verified deployment target is 10.15 (needs update)
- Project codebase: `amplify_secure_storage_test` -- established `@TestOn('windows')` / `@TestOn('linux')` patterns

### Tertiary (LOW confidence)
- Windows WebAuthn API version-to-Windows-build mapping -- inferred from documentation dates, not explicitly mapped

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- dart:ffi, package:ffi, webauthn.dll, libfido2 are all well-established
- Architecture: HIGH (macOS), MEDIUM (Windows) -- macOS is trivial; Windows JSON pass-through is documented but version gating needs care
- Architecture: MEDIUM (Linux) -- libfido2 API is documented but Dart FFI integration is novel
- Pitfalls: HIGH -- identified from official docs and project patterns
- Validation: HIGH -- existing mock pattern (`MockWebAuthnCredentialPlatform`) covers interface-level testing; platform-specific tests follow established `@TestOn` pattern from secure_storage

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (30 days -- stable APIs, unlikely to change)

# Phase 3: Platform Bridges -- iOS, Android, and Web - Research

**Researched:** 2026-03-09
**Domain:** Platform-native WebAuthn/Passkey bridges (iOS, Android, Web) via Flutter Pigeon + JS interop
**Confidence:** HIGH

## Summary

This phase implements the three primary platform bridges that execute WebAuthn ceremonies (create/get credential) using native APIs. Each bridge implements the existing `WebAuthnCredentialPlatform` interface, accepting JSON options and returning JSON responses. iOS and Android use Pigeon-generated method channels (a new dedicated `webauthn_bridge.dart` Pigeon file), while the Web bridge lives in the pure Dart package (`amplify_auth_cognito_dart`) using `package:web` with conditional imports.

The codebase has well-established patterns for all three integration mechanisms: Pigeon bridges (see `native_auth_plugin.dart`), platform plugin registration (see `AmplifyAuthCognitoPlugin` on both iOS/Android), and conditional web imports (see `hosted_ui_platform.dart`). The existing `WebAuthnCredentialPlatform` interface, `PasskeyException` hierarchy, and passkey JSON types are already complete from Phases 1-2. Error mapping happens on the Dart side -- native code throws raw `PlatformException` with error codes, and a Dart mapper converts to `PasskeyException` subtypes.

**Primary recommendation:** Follow established Pigeon and conditional-import patterns exactly. The bridge implementations are thin wrappers -- the complexity is in correctly constructing platform API objects from JSON and extracting base64url-encoded responses.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Create a **new dedicated Pigeon file** (`webauthn_bridge.dart`) in `pigeons/` -- do not extend the existing `NativeAuthBridge`
- All three methods (`createCredential`, `getCredential`, `isPasskeySupported`) are **async** via `@async` annotation
- Register the WebAuthn bridge in the **same plugin class** (`AmplifyAuthCognitoPlugin`) alongside existing OAuth bridge setup
- Use a **shared Darwin implementation file** for iOS (and macOS in Phase 4) -- ASAuthorizationController works on both platforms
- **Coarse grouping** -- map all platform errors to the 5 existing `PasskeyException` subtypes: `NotSupported`, `Cancelled`, `RegistrationFailed`, `AssertionFailed`, `RpMismatch`
- Preserve original platform error in `underlyingException` field for debugging
- Error mapping happens on the **Dart side** -- native code throws raw `PlatformException` with error code/message, Dart layer maps to `PasskeyException` subtypes
- User cancellation is an **exception** (`PasskeyCancelledException`), not a null result
- Web bridge lives in the **pure Dart package** (`amplify_auth_cognito_dart`) with conditional import (`dart.library.js_interop`)
- Uses **`package:web`** for typed JS interop bindings to `navigator.credentials`
- Web bridge **converts JS ArrayBuffer/TypedArray responses to base64url strings** before returning JSON
- **Auto-registers via conditional import** -- stub on non-web, real implementation on web, no explicit registration needed
- `isPasskeySupported()` uses **runtime API availability check** (not OS version check)
  - iOS: `@available(iOS 17.4, *)` check
  - Android: `CredentialManager` availability check
  - Web: Check `navigator.credentials` and `PublicKeyCredential` exist (API existence only)
- Stub implementation for unsupported platforms: `isPasskeySupported()` returns `false`, create/get throw `PasskeyNotSupportedException`

### Claude's Discretion
- Pigeon `@ConfigurePigeon` output paths and codec configuration
- Exact Swift/Kotlin implementation details for wrapping platform APIs
- JS interop extension types and helper utilities for web bridge
- Internal error code constants for Dart-side mapping
- Test structure and mock strategies

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-01 | iOS bridge wraps `ASAuthorizationPlatformPublicKeyCredentialProvider` / `ASAuthorizationController` for create/get (iOS 17.4+) | Swift API patterns documented in Architecture section; error codes mapped; shared Darwin file pattern established |
| PLAT-02 | Android bridge wraps `androidx.credentials.CredentialManager` for `CreatePublicKeyCredentialRequest` / `GetPublicKeyCredentialOption` (API 28+) | Kotlin API patterns documented; dependency versions specified; exception types mapped |
| PLAT-04 | Web bridge calls `navigator.credentials.create()` / `navigator.credentials.get()` via `dart:js_interop` | `package:web` CredentialsContainer API verified; base64url conversion pattern documented; conditional import pattern established |
| PLAT-08 | Platform bridges map platform-specific errors to typed `PasskeyException` subtypes | Complete error mapping tables provided for all three platforms (ASAuthorizationError, CredentialManager exceptions, DOMException) |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pigeon | ^26.0.0 | Flutter method channel code generation | Already used in project for NativeAuthBridge; generates Dart/Swift/Kotlin bindings |
| package:web | ^1.1.1 | Typed JS interop for browser APIs | Already a dependency of `amplify_auth_cognito_dart`; provides `CredentialsContainer`, `PublicKeyCredential` types |
| AuthenticationServices (iOS) | System framework | `ASAuthorizationPlatformPublicKeyCredentialProvider`, `ASAuthorizationController` | Apple's official passkey API, available iOS 17.4+ |
| androidx.credentials | 1.5.0-beta01 or 1.3.0 (stable) | `CredentialManager`, `CreatePublicKeyCredentialRequest`, `GetPublicKeyCredentialOption` | Google's official Credential Manager API for Android passkeys |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| androidx.credentials:credentials-play-services-auth | Same as credentials | Play Services fallback for pre-API 34 | Required for Android API 28-33 devices |
| kotlinx-coroutines-android | 1.10.2 | Async Kotlin operations | Already in project; needed for suspend functions with CredentialManager |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| package:web (web bridge) | web_authn_web package | External dependency, injects JS; package:web is already in project and provides direct typed bindings |
| Pigeon (native bridges) | Platform channels manually | Pigeon is already used in project; manual channels are error-prone and lack type safety |
| Direct ASAuthorizationController | Newer iOS 26 ASAuthorizationAccountCreationProvider | Too new, not relevant for assertion; ASAuthorizationController is the correct API for passkey ceremonies |

**Installation (Android build.gradle additions):**
```groovy
implementation 'androidx.credentials:credentials:1.3.0'
implementation 'androidx.credentials:credentials-play-services-auth:1.3.0'
```

## Architecture Patterns

### Recommended Project Structure
```
packages/auth/amplify_auth_cognito/
  pigeons/
    native_auth_plugin.dart          # Existing
    webauthn_bridge.dart             # NEW: Pigeon definition for WebAuthn bridge
  lib/src/
    native_auth_plugin.g.dart        # Existing generated
    webauthn_bridge.g.dart           # NEW: Generated Dart bindings
    auth_plugin_impl.dart            # MODIFIED: Register WebAuthn bridge
  darwin/Classes/
    pigeons/
      messages.g.swift               # Existing generated
      WebAuthnBridge.g.swift         # NEW: Generated Swift bindings
    WebAuthnBridgeImpl.swift         # NEW: Shared Darwin implementation
  android/src/main/kotlin/.../
    pigeons/
      NativeAuthPluginBindingsPigeon.kt  # Existing
      WebAuthnBridgePigeon.kt            # NEW: Generated Kotlin bindings
    WebAuthnBridgeImpl.kt                # NEW: Android implementation

packages/auth/amplify_auth_cognito_dart/
  lib/src/
    model/webauthn/
      webauthn_credential_platform.dart       # Existing interface
      webauthn_credential_platform_stub.dart  # NEW: Stub (unsupported platforms)
      webauthn_credential_platform_html.dart  # NEW: Web implementation
    auth_plugin_impl.dart                     # MODIFIED: Conditional import for web bridge
```

### Pattern 1: Pigeon Bridge Definition
**What:** Define a new `@HostApi()` abstract class in a dedicated Pigeon file
**When to use:** For all native iOS/Android method channel bridges
**Example:**
```dart
// pigeons/webauthn_bridge.dart
@ConfigurePigeon(
  PigeonOptions(
    copyrightHeader: '../../../tool/license.txt',
    dartOut: 'lib/src/webauthn_bridge.g.dart',
    kotlinOptions: KotlinOptions(
      package: 'com.amazonaws.amplify.amplify_auth_cognito',
    ),
    kotlinOut:
        'android/src/main/kotlin/com/amazonaws/amplify/amplify_auth_cognito/pigeons/WebAuthnBridgePigeon.kt',
    swiftOut: 'darwin/classes/pigeons/WebAuthnBridge.g.swift',
  ),
)
library;

import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class WebAuthnBridgeApi {
  @async
  String createCredential(String optionsJson);

  @async
  String getCredential(String optionsJson);

  @async
  bool isPasskeySupported();
}
```

### Pattern 2: Plugin Registration (Dart side)
**What:** Register Pigeon bridge in `addPlugin()` and inject into state machine
**When to use:** During plugin initialization
**Example:**
```dart
// In auth_plugin_impl.dart addPlugin()
// After existing NativeAuthBridge setup:
if (!zIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  final webAuthnBridge = WebAuthnBridgeApi();
  final webAuthnPlatform = PigeonWebAuthnCredentialPlatform(webAuthnBridge);
  stateMachine.addInstance<WebAuthnCredentialPlatform>(webAuthnPlatform);
}
```

### Pattern 3: Pigeon Bridge Adapter (Dart wrapper)
**What:** Dart class that implements `WebAuthnCredentialPlatform` by delegating to Pigeon-generated API and mapping errors
**When to use:** To bridge between the Pigeon API and the domain interface
**Example:**
```dart
class PigeonWebAuthnCredentialPlatform implements WebAuthnCredentialPlatform {
  PigeonWebAuthnCredentialPlatform(this._bridge);
  final WebAuthnBridgeApi _bridge;

  @override
  Future<String> createCredential(String optionsJson) async {
    try {
      return await _bridge.createCredential(optionsJson);
    } on PlatformException catch (e) {
      throw _mapPlatformException(e, isCreate: true);
    }
  }
  // ... getCredential, isPasskeySupported similar

  PasskeyException _mapPlatformException(PlatformException e, {required bool isCreate}) {
    switch (e.code) {
      case 'cancelled':
        return PasskeyCancelledException(e.message ?? 'User cancelled', underlyingException: e);
      case 'notSupported':
        return PasskeyNotSupportedException(e.message ?? 'Not supported', underlyingException: e);
      case 'rpMismatch':
        return PasskeyRpMismatchException(e.message ?? 'RP mismatch', underlyingException: e);
      default:
        if (isCreate) {
          return PasskeyRegistrationFailedException(e.message ?? 'Registration failed', underlyingException: e);
        }
        return PasskeyAssertionFailedException(e.message ?? 'Assertion failed', underlyingException: e);
    }
  }
}
```

### Pattern 4: Conditional Import for Web Bridge
**What:** Use conditional imports to auto-register web bridge without explicit setup
**When to use:** For the web platform bridge in `amplify_auth_cognito_dart`
**Example:**
```dart
// In amplify_auth_cognito_dart auth_plugin_impl.dart (or a new webauthn_platform.dart)
import 'package:amplify_auth_cognito_dart/src/model/webauthn/webauthn_credential_platform_stub.dart'
    if (dart.library.js_interop) 'package:amplify_auth_cognito_dart/src/model/webauthn/webauthn_credential_platform_html.dart';

// Factory or function that returns the platform-appropriate instance
WebAuthnCredentialPlatform createWebAuthnPlatform() => WebAuthnCredentialPlatformImpl();
```

### Pattern 5: iOS/Darwin Swift Implementation
**What:** Implement the Pigeon-generated protocol using ASAuthorizationController
**When to use:** For iOS (and macOS in Phase 4) passkey ceremonies
**Example:**
```swift
// darwin/Classes/WebAuthnBridgeImpl.swift
import AuthenticationServices
import Foundation

class WebAuthnBridgeImpl: NSObject, WebAuthnBridgeApi {
    func isPasskeySupported(completion: @escaping (Result<Bool, any Error>) -> Void) {
        if #available(iOS 17.4, macOS 13.5, *) {
            completion(.success(true))
        } else {
            completion(.success(false))
        }
    }

    func createCredential(optionsJson: String, completion: @escaping (Result<String, any Error>) -> Void) {
        guard #available(iOS 17.4, macOS 13.5, *) else {
            completion(.failure(FlutterError(code: "notSupported", message: "Passkeys not supported", details: nil)))
            return
        }
        // Parse JSON, create ASAuthorizationPlatformPublicKeyCredentialProvider,
        // build registration request, perform with ASAuthorizationController
        // ... (delegate callbacks serialize result to JSON)
    }

    func getCredential(optionsJson: String, completion: @escaping (Result<String, any Error>) -> Void) {
        guard #available(iOS 17.4, macOS 13.5, *) else {
            completion(.failure(FlutterError(code: "notSupported", message: "Passkeys not supported", details: nil)))
            return
        }
        // Parse JSON, create assertion request, perform with ASAuthorizationController
    }
}
```

### Pattern 6: Android Kotlin Implementation
**What:** Implement Pigeon-generated interface using CredentialManager
**When to use:** For Android passkey ceremonies
**Example:**
```kotlin
// android/src/main/kotlin/.../WebAuthnBridgeImpl.kt
class WebAuthnBridgeImpl(private val context: Context) : WebAuthnBridgeApi {
    private val credentialManager = CredentialManager.create(context)

    override fun createCredential(optionsJson: String, callback: (Result<String>) -> Unit) {
        val activity = mainActivity ?: run {
            callback(Result.failure(FlutterError("notSupported", "No activity", null)))
            return
        }
        val request = CreatePublicKeyCredentialRequest(requestJson = optionsJson)
        scope.launch {
            try {
                val result = credentialManager.createCredential(activity, request)
                val response = result as CreatePublicKeyCredentialResponse
                callback(Result.success(response.registrationResponseJson))
            } catch (e: CreateCredentialCancellationException) {
                callback(Result.failure(FlutterError("cancelled", e.message, null)))
            } catch (e: CreateCredentialException) {
                callback(Result.failure(FlutterError("registrationFailed", e.message, null)))
            }
        }
    }
    // ... getCredential, isPasskeySupported similar
}
```

### Pattern 7: Web Bridge Implementation
**What:** Implement WebAuthnCredentialPlatform using `package:web` JS interop
**When to use:** For the web platform
**Example:**
```dart
// webauthn_credential_platform_html.dart
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebAuthnCredentialPlatformImpl implements WebAuthnCredentialPlatform {
  @override
  Future<bool> isPasskeySupported() async {
    final credentials = web.window.navigator.credentials;
    // Check if PublicKeyCredential exists
    return credentials != null && web.window.has('PublicKeyCredential');
  }

  @override
  Future<String> createCredential(String optionsJson) async {
    final options = json.decode(optionsJson) as Map<String, dynamic>;
    // Convert base64url strings to ArrayBuffer for challenge, user.id, etc.
    // Call navigator.credentials.create({publicKey: ...})
    // Convert ArrayBuffer responses back to base64url strings
    // Return JSON string
  }
}
```

### Anti-Patterns to Avoid
- **Sharing Pigeon file with NativeAuthBridge:** The user locked the decision to create a separate file. Combining them would tangle unrelated bridge lifecycles.
- **Error mapping on native side:** Error mapping is explicitly Dart-side. Native code should throw raw errors with consistent error codes (`cancelled`, `notSupported`, `registrationFailed`, `assertionFailed`, `rpMismatch`).
- **Checking OS version instead of API availability:** Use `@available` (iOS) and CredentialManager availability (Android) for runtime checks.
- **Returning null for cancellation:** User cancellation must throw `PasskeyCancelledException`, not return null. This is consistent with the existing `UserCancelledException` pattern.
- **Base64 vs base64url:** WebAuthn uses base64url without padding. The project already has `base64UrlEncode`/`base64UrlDecode` utilities. Use them consistently.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Method channel serialization | Custom platform channels | Pigeon code generation | Type-safe, handles async, generates both ends |
| Base64url encoding/decoding | Custom encoder | Existing `base64UrlEncode`/`base64UrlDecode` in `util/base64url_encode.dart` | Already handles padding normalization |
| Android passkey credential flow | Direct FIDO2 API calls | `androidx.credentials.CredentialManager` | Unified API, handles Play Services fallback, Google-recommended |
| iOS passkey credential flow | Custom Security framework calls | `ASAuthorizationPlatformPublicKeyCredentialProvider` + `ASAuthorizationController` | Apple's official API, handles biometric prompt |
| Web WebAuthn calls | Injected JavaScript | `package:web` `CredentialsContainer.create()`/`.get()` | Already a project dependency, typed bindings, no JS injection needed |
| JSON serialization for Android CredentialManager | Custom JSON builder | Pass `optionsJson` directly to `CreatePublicKeyCredentialRequest(requestJson)` | Android CredentialManager accepts raw JSON strings natively |

**Key insight:** Android's `CredentialManager` accepts and returns raw JSON strings directly, which aligns perfectly with the JSON string boundary design. iOS requires manual construction of `ASAuthorization*` objects from parsed JSON and manual extraction of response data. Web requires ArrayBuffer-to-base64url conversion.

## Common Pitfalls

### Pitfall 1: iOS ASAuthorizationController Delegate Lifecycle
**What goes wrong:** The delegate and presentation context provider get deallocated before the callback fires, causing silent failures.
**Why it happens:** Swift's `ASAuthorizationController` holds a weak reference to its delegate. If the delegate object is a local variable, ARC may deallocate it.
**How to avoid:** Store the delegate (and the controller itself) as a property on the bridge implementation class. Release after completion callback fires.
**Warning signs:** Ceremony UI appears but completion handler never called; no error, no success.

### Pitfall 2: Android Activity Context Required
**What goes wrong:** `CredentialManager.createCredential()` and `getCredential()` require an `Activity`, not just a `Context`. Using application context causes crashes or silent failures.
**Why it happens:** The credential manager needs to show UI (biometric prompt, account picker) which requires an activity window.
**How to avoid:** Access the activity from `ActivityAware` interface (same pattern as existing `AmplifyAuthCognitoPlugin`). Check for null activity before attempting operations.
**Warning signs:** `NullPointerException` or "No activity" errors during credential operations.

### Pitfall 3: Web ArrayBuffer/TypedArray to base64url Conversion
**What goes wrong:** WebAuthn browser APIs return `ArrayBuffer` objects for credential IDs, authenticator data, client data JSON, etc. These must be converted to base64url strings before the JSON response can be constructed.
**Why it happens:** The W3C WebAuthn API uses binary types, but the JSON string boundary contract requires base64url strings.
**How to avoid:** Use `dart:js_interop` to access the `ArrayBuffer` as `Uint8Array`, convert to `Dart List<int>`, then use `base64UrlEncode()`. For inputs (challenge, user.id), do the reverse: `base64UrlDecode()` to bytes, then create JS `Uint8Array`.
**Warning signs:** JSON containing `[object ArrayBuffer]` strings, or "type error" when passing Dart strings where ArrayBuffer is expected.

### Pitfall 4: Web PublicKeyCredentialCreationOptions Type Conversion
**What goes wrong:** `navigator.credentials.create()` expects a specific JS object shape with `ArrayBuffer` fields, not a plain JSON object. Passing the raw JSON options map directly fails.
**Why it happens:** The browser API expects `{ publicKey: { challenge: ArrayBuffer, user: { id: ArrayBuffer, ...}, ... } }`, not JSON strings.
**How to avoid:** Parse the JSON options in Dart, convert base64url string fields to `JSArrayBuffer` via `Uint8List(...).buffer.toJS`, construct the JS options object using `dart:js_interop` object literals or extension types.
**Warning signs:** `TypeError: Failed to execute 'create' on 'CredentialsContainer'` or `DataError` from browser.

### Pitfall 5: Pigeon Code Generation Must Be Run After Defining Bridge
**What goes wrong:** Forgetting to run `dart run pigeon --input pigeons/webauthn_bridge.dart` after creating or modifying the Pigeon definition, leading to missing generated files.
**Why it happens:** Pigeon files are not auto-generated -- they require explicit code generation.
**How to avoid:** Run pigeon code generation immediately after creating the Pigeon definition file. Verify all three output files are generated (Dart, Swift, Kotlin).
**Warning signs:** Import errors for `webauthn_bridge.g.dart`, missing Swift/Kotlin protocols.

### Pitfall 6: Android CredentialManager JSON Response Format
**What goes wrong:** Android `CreatePublicKeyCredentialResponse.registrationResponseJson` returns a JSON string that already contains base64url-encoded values in the W3C `RegistrationResponseJSON` format. Double-encoding produces corrupt data.
**Why it happens:** Developers may try to re-encode binary fields that are already base64url-encoded.
**How to avoid:** Pass `registrationResponseJson` / `authenticationResponseJson` directly as the return value. The Android CredentialManager handles the binary-to-base64url conversion internally.
**Warning signs:** Credential verification failures on the server due to double-encoded values.

## Code Examples

### iOS: Registration (Create Credential) - Swift
```swift
// Source: Apple ASAuthorizationPlatformPublicKeyCredentialProvider docs
@available(iOS 17.4, macOS 13.5, *)
private func performRegistration(optionsJson: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let data = optionsJson.data(using: .utf8),
          let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let challengeB64 = options["challenge"] as? String,
          let challengeData = Data(base64URLEncoded: challengeB64),
          let rp = options["rp"] as? [String: Any],
          let rpId = rp["id"] as? String,
          let user = options["user"] as? [String: Any],
          let userIdB64 = user["id"] as? String,
          let userIdData = Data(base64URLEncoded: userIdB64),
          let userName = user["name"] as? String else {
        completion(.failure(FlutterError(code: "registrationFailed", message: "Invalid options JSON", details: nil)))
        return
    }

    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
    let request = provider.createCredentialRegistrationRequest(
        challenge: challengeData,
        name: userName,
        userID: userIdData
    )

    let controller = ASAuthorizationController(authorizationRequests: [request])
    // Store controller + delegate, set presentationContextProvider, performRequests()
}
```

### iOS: Assertion (Get Credential) - Swift
```swift
@available(iOS 17.4, macOS 13.5, *)
private func performAssertion(optionsJson: String, completion: @escaping (Result<String, Error>) -> Void) {
    guard let data = optionsJson.data(using: .utf8),
          let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let challengeB64 = options["challenge"] as? String,
          let challengeData = Data(base64URLEncoded: challengeB64),
          let rpId = options["rpId"] as? String else {
        completion(.failure(FlutterError(code: "assertionFailed", message: "Invalid options JSON", details: nil)))
        return
    }

    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
    let request = provider.createCredentialAssertionRequest(challenge: challengeData)

    // Set allowedCredentials from options["allowCredentials"] if present

    let controller = ASAuthorizationController(authorizationRequests: [request])
    // Store controller + delegate, set presentationContextProvider, performRequests()
}
```

### Android: Registration (Create Credential) - Kotlin
```kotlin
// Source: Android developer docs - Create a passkey
suspend fun createCredential(activity: Activity, optionsJson: String): String {
    val request = CreatePublicKeyCredentialRequest(requestJson = optionsJson)
    val result = credentialManager.createCredential(activity, request)
    val response = result as CreatePublicKeyCredentialResponse
    return response.registrationResponseJson
}
```

### Android: Assertion (Get Credential) - Kotlin
```kotlin
// Source: Android developer docs - Sign in with a passkey
suspend fun getCredential(activity: Activity, optionsJson: String): String {
    val option = GetPublicKeyCredentialOption(requestJson = optionsJson)
    val request = GetCredentialRequest.Builder()
        .addCredentialOption(option)
        .build()
    val result = credentialManager.getCredential(activity, request)
    val credential = result.credential as PublicKeyCredential
    return credential.authenticationResponseJson
}
```

### Web: Base64url ArrayBuffer Conversion
```dart
// Converting between Dart base64url strings and JS ArrayBuffer
import 'dart:js_interop';
import 'dart:typed_data';

JSArrayBuffer base64UrlToArrayBuffer(String base64url) {
  final bytes = base64UrlDecode(base64url); // from util/base64url_encode.dart
  return Uint8List.fromList(bytes).buffer.toJS;
}

String arrayBufferToBase64Url(JSArrayBuffer buffer) {
  final bytes = buffer.toDart.asUint8List();
  return base64UrlEncode(bytes.toList()); // from util/base64url_encode.dart
}
```

### Dart Error Mapping
```dart
// Error code constants for native-to-Dart mapping
abstract final class WebAuthnErrorCodes {
  static const cancelled = 'cancelled';
  static const notSupported = 'notSupported';
  static const registrationFailed = 'registrationFailed';
  static const assertionFailed = 'assertionFailed';
  static const rpMismatch = 'rpMismatch';
}
```

## Error Mapping Tables

### iOS ASAuthorizationError to Error Codes
| ASAuthorizationError.Code | Pigeon Error Code | PasskeyException Subtype |
|---------------------------|-------------------|--------------------------|
| `.canceled` | `cancelled` | `PasskeyCancelledException` |
| `.failed` | `registrationFailed` or `assertionFailed` | `PasskeyRegistrationFailedException` / `PasskeyAssertionFailedException` |
| `.invalidResponse` | `registrationFailed` or `assertionFailed` | `PasskeyRegistrationFailedException` / `PasskeyAssertionFailedException` |
| `.notHandled` | `notSupported` | `PasskeyNotSupportedException` |
| `.unknown` | `registrationFailed` or `assertionFailed` | `PasskeyRegistrationFailedException` / `PasskeyAssertionFailedException` |
| `.matchedExcludedCredential` | `registrationFailed` | `PasskeyRegistrationFailedException` |

### Android CredentialManager Exceptions to Error Codes
| Exception Type | Pigeon Error Code | PasskeyException Subtype |
|----------------|-------------------|--------------------------|
| `CreateCredentialCancellationException` | `cancelled` | `PasskeyCancelledException` |
| `GetCredentialCancellationException` | `cancelled` | `PasskeyCancelledException` |
| `CreateCredentialInterruptedException` | `registrationFailed` | `PasskeyRegistrationFailedException` |
| `GetCredentialInterruptedException` | `assertionFailed` | `PasskeyAssertionFailedException` |
| `NoCredentialException` | `assertionFailed` | `PasskeyAssertionFailedException` |
| `CreatePublicKeyCredentialDomException` | `registrationFailed` | `PasskeyRegistrationFailedException` |
| `CreateCredentialProviderConfigurationException` | `notSupported` | `PasskeyNotSupportedException` |
| Other `CreateCredentialException` | `registrationFailed` | `PasskeyRegistrationFailedException` |
| Other `GetCredentialException` | `assertionFailed` | `PasskeyAssertionFailedException` |

### Web DOMException to PasskeyException
| DOMException.name | PasskeyException Subtype |
|-------------------|--------------------------|
| `NotAllowedError` | `PasskeyCancelledException` (user cancelled) |
| `InvalidStateError` | `PasskeyRegistrationFailedException` (credential already exists in excludeCredentials) |
| `SecurityError` | `PasskeyRpMismatchException` (RP ID / origin mismatch or non-HTTPS) |
| `AbortError` | `PasskeyCancelledException` (ceremony aborted) |
| `ConstraintError` | `PasskeyRegistrationFailedException` |
| Other/unknown | `PasskeyRegistrationFailedException` or `PasskeyAssertionFailedException` |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Android FIDO2 API (`com.google.android.gms.fido`) | `androidx.credentials.CredentialManager` | 2023 | Unified API, handles passkeys + passwords + federated |
| iOS manual Security framework | `ASAuthorizationPlatformPublicKeyCredentialProvider` | iOS 16+ (full passkey iOS 17.4+) | Built-in iCloud Keychain sync, biometric prompt |
| Dart `dart:js` interop | `dart:js_interop` + `package:web` extension types | Dart 3.3+ | Type-safe, tree-shakeable, no dynamic JS calls |
| Flutter WebAuthn: inject JS via script tag | `package:web` direct bindings | Current | No JS injection needed, fully typed |

**Deprecated/outdated:**
- `dart:html`: Replaced by `package:web` with `dart:js_interop`
- `com.google.android.gms.fido.fido2`: Replaced by `androidx.credentials`
- `ASAuthorizationPlatformPublicKeyCredentialProvider` on iOS < 17.4: Does not support passkeys for platform authenticators

## Open Questions

1. **Data(base64URLEncoded:) availability in Swift**
   - What we know: Swift Foundation may not have a built-in `Data(base64URLEncoded:)` initializer. Standard `Data(base64Encoded:)` uses regular base64.
   - What's unclear: Whether to use a custom extension or if recent Swift versions added this.
   - Recommendation: Write a small `Data` extension that converts base64url to base64 (replace `-` with `+`, `_` with `/`, add padding) then decode. This is simple and well-understood.

2. **iOS presentationContextProvider window reference**
   - What we know: `ASAuthorizationController` needs a `ASAuthorizationControllerPresentationContextProviding` delegate that returns a `UIWindow`/`NSWindow`.
   - What's unclear: How to reliably get the Flutter app's key window in modern iOS (post-UIScene).
   - Recommendation: Use the existing plugin registrar's view controller to find the window, similar to how the existing `HostedUIFlow` accesses the presentation context.

3. **Android CredentialManager vs minSdkVersion 24**
   - What we know: The project's `minSdkVersion` is 24, but `CredentialManager` requires API 28+ (via Play Services fallback). The CONTEXT.md specifies API 28+.
   - What's unclear: Whether the bridge should compile on API 24 and fail gracefully at runtime, or if minSdk should be bumped.
   - Recommendation: Keep minSdk 24, use runtime checks for CredentialManager availability. `isPasskeySupported()` returns `false` on API < 28.

## Validation Architecture

### Testing Strategy Overview

Platform bridges present a unique testing challenge: the core WebAuthn APIs (`ASAuthorizationController`, `CredentialManager`, `navigator.credentials`) require real hardware with biometric capabilities and cannot be meaningfully mocked at the native API level. The validation strategy therefore layers tests across four levels, with the majority of automated coverage at the Dart layer.

### Test Layers

| Layer | What It Tests | Can Automate? | Framework |
|-------|---------------|---------------|-----------|
| **Dart unit tests** | Error mapping, Pigeon adapter, stub behavior, conditional imports | YES | `package:test` (pure Dart), `flutter_test` (Flutter) |
| **Android unit tests** | Error code mapping, JSON handling, CredentialManager exception paths | YES (with mocks) | JUnit 4 + Mockito-Kotlin + Robolectric (already in project) |
| **iOS unit tests** | JSON parsing, base64url conversion, error code mapping | PARTIAL (XCTest, but no simulator passkey support) | XCTest (limited -- no passkey API on simulator) |
| **Integration / E2E** | Full ceremony end-to-end with real Cognito backend | MANUAL only (requires real device + biometrics) | Manual QA |

### Dart-Layer Tests (Primary Automated Coverage)

**1. PigeonWebAuthnCredentialPlatform error mapper tests**
```dart
// Test that PlatformException with each error code maps to correct PasskeyException
group('PigeonWebAuthnCredentialPlatform', () {
  test('maps cancelled error code to PasskeyCancelledException', () async {
    final bridge = MockWebAuthnBridgeApi();
    when(() => bridge.createCredential(any()))
        .thenThrow(PlatformException(code: 'cancelled', message: 'User cancelled'));
    final platform = PigeonWebAuthnCredentialPlatform(bridge);
    expect(
      () => platform.createCredential('{}'),
      throwsA(isA<PasskeyCancelledException>()),
    );
  });
  // Similar for: notSupported, rpMismatch, registrationFailed, assertionFailed
  // Test that unknown error codes default to RegistrationFailed (create) / AssertionFailed (get)
  // Test that underlyingException preserves original PlatformException
});
```

**2. Stub platform tests**
```dart
group('WebAuthnCredentialPlatformStub', () {
  test('isPasskeySupported returns false', () async {
    final stub = WebAuthnCredentialPlatformImpl(); // stub version
    expect(await stub.isPasskeySupported(), isFalse);
  });
  test('createCredential throws PasskeyNotSupportedException', () async {
    final stub = WebAuthnCredentialPlatformImpl();
    expect(() => stub.createCredential('{}'), throwsA(isA<PasskeyNotSupportedException>()));
  });
  test('getCredential throws PasskeyNotSupportedException', () async {
    final stub = WebAuthnCredentialPlatformImpl();
    expect(() => stub.getCredential('{}'), throwsA(isA<PasskeyNotSupportedException>()));
  });
});
```

**3. Web bridge unit tests (Dart tests with `@TestOn('browser')`)**
- Test base64url-to-ArrayBuffer and ArrayBuffer-to-base64url conversion helpers
- Test JSON option construction (verify correct field mapping)
- Test error handling for DOMException types (mock `navigator.credentials` to throw specific DOMExceptions)
- Note: Full ceremony cannot be tested without a real browser WebAuthn environment, but helper functions and error mapping CAN be tested

**4. Sign-in state machine integration test (already partially exists)**
The existing `sign_in_webauthn_test.dart` in `amplify_auth_cognito_test` provides the pattern: inject a `MockWebAuthnCredentialPlatform` into the state machine, configure mock Cognito responses, and verify the full sign-in flow. This test should be extended to cover:
- Bridge returns valid credential JSON and sign-in completes
- Bridge throws each `PasskeyException` subtype and state machine propagates correctly
- Bridge throws unexpected error and state machine handles gracefully

### Android Unit Tests

The project already has `AmplifyAuthCognitoPluginTest.kt` with JUnit + Mockito-Kotlin + Robolectric. Extend this pattern for `WebAuthnBridgeImpl`:

```kotlin
@RunWith(RobolectricTestRunner::class)
class WebAuthnBridgeImplTest {
    // Mock CredentialManager to throw specific exceptions
    @Test
    fun createCredential_cancellation_throwsCancelledError() {
        val mockCredentialManager = mock<CredentialManager> {
            onBlocking { createCredential(any(), any()) } doThrow
                CreateCredentialCancellationException("user cancelled")
        }
        val bridge = WebAuthnBridgeImpl(mockCredentialManager, mockActivity)
        bridge.createCredential("{}", callback)
        // Verify callback receives FlutterError with code "cancelled"
    }

    @Test
    fun getCredential_noCredential_throwsAssertionFailedError() { /* ... */ }

    @Test
    fun isPasskeySupported_apiBelow28_returnsFalse() { /* ... */ }
}
```

**What CAN be tested without hardware:**
- Exception-to-error-code mapping (mock `CredentialManager` to throw each exception type)
- `isPasskeySupported()` runtime check behavior (use Robolectric SDK configuration)
- JSON pass-through (verify `optionsJson` is forwarded to `CreatePublicKeyCredentialRequest` unchanged)
- Activity null check (verify error when no activity attached)

**What CANNOT be tested without hardware:**
- Actual credential creation/retrieval (requires biometric hardware)
- Play Services fallback behavior on real devices
- Biometric prompt UI interaction

### iOS Testing Constraints

iOS WebAuthn testing is the most constrained. `ASAuthorizationController` does not work on the iOS Simulator -- it requires a physical device with Face ID / Touch ID. XCTest can be used for:

**What CAN be tested (XCTest on simulator):**
- JSON parsing logic (parse options JSON, verify correct field extraction)
- Base64url encoding/decoding extension on `Data`
- Error code string generation (verify correct error codes for each `ASAuthorizationError.Code`)
- `isPasskeySupported()` returns `false` on simulator (since `#available(iOS 17.4, *)` resolves differently)

**What CANNOT be tested (requires physical device):**
- `ASAuthorizationController` delegate callbacks
- Actual credential creation/assertion
- Presentation context provider behavior

**Recommendation:** Keep iOS native tests minimal (JSON parsing + base64url helpers only). Rely on the Dart-layer `PigeonWebAuthnCredentialPlatform` tests for error mapping coverage, since error mapping is Dart-side per the locked decision.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated? | Test Location |
|--------|----------|-----------|------------|---------------|
| PLAT-01 | iOS create/get credential | Manual E2E | NO -- requires physical iOS device | Manual QA on device |
| PLAT-01 | iOS JSON parsing + base64url | Unit | YES | `darwin/Tests/` (XCTest) or Dart-side mock |
| PLAT-01 | iOS error code mapping | Unit | YES | Dart `PigeonWebAuthnCredentialPlatform` tests |
| PLAT-02 | Android create/get credential | Manual E2E | NO -- requires device with biometrics | Manual QA on device |
| PLAT-02 | Android exception mapping | Unit | YES | `android/src/test/` (JUnit + Mockito) |
| PLAT-02 | Android JSON pass-through | Unit | YES | `android/src/test/` (JUnit) |
| PLAT-02 | Android isPasskeySupported | Unit | YES | `android/src/test/` (Robolectric) |
| PLAT-04 | Web create/get credential | Manual E2E | NO -- requires HTTPS + WebAuthn-capable browser | Manual QA in browser |
| PLAT-04 | Web base64url/ArrayBuffer conversion | Unit | YES | Dart `@TestOn('browser')` test |
| PLAT-04 | Web DOMException error mapping | Unit | YES | Dart `@TestOn('browser')` test |
| PLAT-04 | Web isPasskeySupported | Unit | YES | Dart `@TestOn('browser')` test |
| PLAT-08 | All platform error mapping to PasskeyException | Unit | YES | Dart `PigeonWebAuthnCredentialPlatform` tests |
| PLAT-08 | Stub throws PasskeyNotSupportedException | Unit | YES | Dart stub platform tests |

### Mock/Stub Approaches

**Dart layer (primary):**
- `MockWebAuthnCredentialPlatform` -- already exists in `sign_in_webauthn_test.dart`. Implements `WebAuthnCredentialPlatform` with configurable callbacks for `onGetCredential`, `onCreateCredential`, `onIsPasskeySupported`.
- `MockWebAuthnBridgeApi` -- mock of the Pigeon-generated `WebAuthnBridgeApi` class. Use to test the `PigeonWebAuthnCredentialPlatform` adapter in isolation.
- For Flutter widget tests: register a mock `WebAuthnCredentialPlatform` via `stateMachine.addInstance<WebAuthnCredentialPlatform>(mock)`.

**Android layer:**
- Mock `CredentialManager` with Mockito-Kotlin to simulate exception paths
- Mock `Activity` for null-activity error paths
- Use Robolectric to control `Build.VERSION.SDK_INT` for API level checks

**iOS layer:**
- No practical mock for `ASAuthorizationController` -- it is a system UI component
- Test helper functions (JSON parsing, base64url) in isolation
- Rely on Dart-side mocks for integration testing

**Web layer:**
- For `@TestOn('browser')` tests, the actual browser `navigator.credentials` API exists but cannot create credentials without user gesture + HTTPS
- Test conversion helpers and error mapping in isolation
- Mock web APIs using `dart:js_interop` stubs where possible

### Validation Commands

```bash
# Dart unit tests (PigeonWebAuthnCredentialPlatform, stub, error mapping)
cd packages/auth/amplify_auth_cognito && dart test test/

# Dart test for auth_cognito_test package (sign-in WebAuthn integration)
cd packages/auth/amplify_auth_cognito_test && dart test test/state/sign_in_webauthn_test.dart

# Android unit tests (WebAuthnBridgeImpl error mapping)
cd packages/auth/amplify_auth_cognito/android && ./gradlew testDebugUnitTest

# iOS tests (limited -- JSON parsing, base64url helpers only)
# Run via Xcode or: xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator'

# Web tests (base64url conversion, conditional import)
cd packages/auth/amplify_auth_cognito_dart && dart test --platform chrome test/
```

### Wave 0 Gaps (Tests Needed Before Implementation)

- [ ] `packages/auth/amplify_auth_cognito/test/webauthn_bridge_test.dart` -- Dart unit tests for `PigeonWebAuthnCredentialPlatform` error mapping adapter
- [ ] `packages/auth/amplify_auth_cognito_dart/test/webauthn_credential_platform_stub_test.dart` -- stub behavior (returns false, throws not-supported)
- [ ] `packages/auth/amplify_auth_cognito/android/src/test/kotlin/.../WebAuthnBridgeImplTest.kt` -- Android exception mapping tests
- [ ] Extension of `sign_in_webauthn_test.dart` to cover error propagation from bridge to state machine

### Key Validation Principle

Since all three platform bridges share the same JSON string contract (`WebAuthnCredentialPlatform` interface), the most valuable automated tests are at the **Dart adapter layer** where error mapping happens. A single `PigeonWebAuthnCredentialPlatform` test suite covers the contract for both iOS and Android simultaneously, because native code only throws raw `PlatformException` with error codes, and the Dart adapter does the mapping.

The actual WebAuthn ceremonies (biometric prompt, credential creation) are inherently manual-test-only. Do not attempt to automate these -- they require real hardware, real biometrics, and a real Cognito backend. Focus automated testing on: (1) error mapping correctness, (2) JSON contract compliance, (3) stub/fallback behavior, (4) state machine integration with mocked bridge.

## Sources

### Primary (HIGH confidence)
- Apple ASAuthorizationPlatformPublicKeyCredentialProvider docs: https://developer.apple.com/documentation/authenticationservices/asauthorizationplatformpublickeycredentialprovider
- Apple ASAuthorizationError.Code docs: https://developer.apple.com/documentation/authenticationservices/asauthorizationerror-swift.struct/code
- Android CredentialManager docs: https://developer.android.com/identity/sign-in/credential-provider
- Android Create a passkey guide: https://developer.android.com/identity/passkeys/create-passkeys
- Android CreatePublicKeyCredentialRequest API: https://developer.android.com/reference/androidx/credentials/CreatePublicKeyCredentialRequest
- Android GetCredentialException API: https://developer.android.com/reference/android/credentials/GetCredentialException
- package:web CredentialsContainer: https://pub.dev/documentation/web/0.5.1/web/CredentialsContainer-extension-type.html
- MDN CredentialsContainer.create(): https://developer.mozilla.org/en-US/docs/Web/API/CredentialsContainer/create
- Existing codebase: `native_auth_plugin.dart` Pigeon definition, `AmplifyAuthCognitoPlugin` (Swift/Kotlin), `hosted_ui_platform.dart` conditional imports
- Existing test patterns: `AmplifyAuthCognitoPluginTest.kt` (Android), `hosted_ui_platform_flutter_test.dart` (Dart/Flutter), `sign_in_webauthn_test.dart` (state machine integration)

### Secondary (MEDIUM confidence)
- Android Credential Manager troubleshooting: https://developer.android.com/identity/sign-in/credential-manager-troubleshooting-guide
- WebAuthn error guide (Corbado): https://www.corbado.com/blog/webauthn-errors
- androidx.credentials release notes: https://developer.android.com/jetpack/androidx/releases/credentials

### Tertiary (LOW confidence)
- None -- all findings verified with official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries are already project dependencies or well-documented official APIs
- Architecture: HIGH - patterns directly derived from existing codebase (`NativeAuthBridge`, `hosted_ui_platform.dart`)
- Pitfalls: HIGH - based on official documentation and well-known WebAuthn implementation challenges
- Error mapping: MEDIUM - error code mapping is well-documented but edge cases (e.g., `NotAllowedError` ambiguity on web) require runtime verification
- Validation: HIGH - test patterns derived from existing project tests (`AmplifyAuthCognitoPluginTest.kt`, `sign_in_webauthn_test.dart`)

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable -- all APIs are released and documented)

---
wave: 1
depends_on: []
files_modified:
  - packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart
  - packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart
requirements: [PLAT-07]
autonomous: true
---

# Plan 04: WebAuthnCredentialPlatform Abstract Interface

## Objective

Define the abstract `WebAuthnCredentialPlatform` interface with the three minimal methods that platform bridges must implement: `createCredential`, `getCredential`, and `isPasskeySupported`. This establishes the contract that iOS, Android, Web, macOS, Windows, and Linux bridges will implement in later phases.

## Context

Both amplify-swift and amplify-android use a minimal platform bridge interface. The Flutter implementation follows the same pattern: all Cognito API logic stays in Dart, and only the actual WebAuthn ceremony (biometric/passkey prompt) crosses the platform boundary. The interface accepts and returns JSON strings, keeping the serialization layer in Dart (using the types from Plan 02).

See `.planning/research/native-sdk-references.md` section 4 for the recommended Flutter interface:
```
createCredential(String optionsJson) -> String responseJson
getCredential(String optionsJson) -> String responseJson
isPasskeySupported() -> bool
```

## Tasks

### Task 1: Create WebAuthnCredentialPlatform abstract interface

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/webauthn_credential_platform.dart`

Create a new file with standard license header. Define the abstract interface:

```dart
/// {@template amplify_auth_cognito_dart.webauthn_credential_platform}
/// Abstract interface for platform-specific WebAuthn/passkey operations.
///
/// Platform implementations (iOS, Android, Web, macOS, Windows, Linux)
/// must implement this interface to provide WebAuthn ceremony support.
///
/// The interface operates on JSON strings to keep serialization logic
/// in the shared Dart layer. The JSON formats follow the W3C WebAuthn
/// Level 3 specification dictionaries.
/// {@endtemplate}
abstract interface class WebAuthnCredentialPlatform {
  /// Creates a new passkey credential on the device.
  ///
  /// [optionsJson] is a JSON-serialized `PublicKeyCredentialCreationOptions`
  /// object from Cognito's `StartWebAuthnRegistration` response.
  ///
  /// Returns a JSON-serialized `RegistrationResponseJSON` (W3C WebAuthn Level 3)
  /// containing the newly created credential.
  ///
  /// Throws [PasskeyNotSupportedException] if passkeys are not supported.
  /// Throws [PasskeyCancelledException] if the user cancels the ceremony.
  /// Throws [PasskeyRegistrationFailedException] if credential creation fails.
  Future<String> createCredential(String optionsJson);

  /// Retrieves a passkey credential assertion for authentication.
  ///
  /// [optionsJson] is a JSON-serialized `PublicKeyCredentialRequestOptions`
  /// object from Cognito's `CREDENTIAL_REQUEST_OPTIONS` challenge parameter.
  ///
  /// Returns a JSON-serialized `AuthenticationResponseJSON` (W3C WebAuthn Level 3)
  /// containing the assertion result.
  ///
  /// Throws [PasskeyNotSupportedException] if passkeys are not supported.
  /// Throws [PasskeyCancelledException] if the user cancels the ceremony.
  /// Throws [PasskeyAssertionFailedException] if credential retrieval fails.
  Future<String> getCredential(String optionsJson);

  /// Returns whether the current device/platform supports passkeys.
  ///
  /// This is a lightweight check that does not trigger any UI prompts.
  /// It checks for platform API availability (e.g., iOS 17.4+, Android API 28+,
  /// browser WebAuthn support).
  Future<bool> isPasskeySupported();
}
```

Key design decisions:
- Use `abstract interface class` per codebase conventions (see `packages/amplify_core/lib/src/plugin/amplify_plugin_interface.dart` for reference pattern)
- Methods return `Future` since all platform operations are async
- `isPasskeySupported` returns `Future<bool>` (not `bool`) because some platforms need async checks (e.g., Android CredentialManager availability)
- JSON string parameters/returns keep the interface minimal and avoid coupling to specific Dart types
- Documented exception types tell implementors which exceptions to throw

### Task 2: Export from barrel file

**File:** `packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart`

Add export for the new interface file:
```dart
export 'src/model/webauthn/webauthn_credential_platform.dart';
```

If Plan 02 has already been applied, this export can be placed adjacent to the `passkey_types.dart` export.

## Verification

1. `dart analyze packages/auth/amplify_auth_cognito_dart` -- no errors
2. `WebAuthnCredentialPlatform` is accessible from `package:amplify_auth_cognito_dart/amplify_auth_cognito_dart.dart`
3. The interface can be implemented by a test class:
   ```dart
   class MockWebAuthnPlatform implements WebAuthnCredentialPlatform {
     @override Future<String> createCredential(String optionsJson) async => '{}';
     @override Future<String> getCredential(String optionsJson) async => '{}';
     @override Future<bool> isPasskeySupported() async => true;
   }
   ```
4. All public members have dartdoc comments
5. The interface uses `abstract interface class` syntax

## must_haves

- [ ] `WebAuthnCredentialPlatform` is defined as `abstract interface class`
- [ ] `createCredential(String optionsJson)` method returns `Future<String>`
- [ ] `getCredential(String optionsJson)` method returns `Future<String>`
- [ ] `isPasskeySupported()` method returns `Future<bool>`
- [ ] Interface is exported from the package barrel file
- [ ] All methods have dartdoc documenting parameters, return values, and thrown exceptions

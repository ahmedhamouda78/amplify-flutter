// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

// ignore: implementation_imports
import 'package:amplify_auth_cognito_dart/src/model/webauthn/webauthn_credential_platform.dart';
import 'package:amplify_core/amplify_core.dart';

/// Mock implementation of WebAuthnCredentialPlatform for testing.
///
/// Each method takes an optional callback. If provided, the callback is invoked;
/// otherwise, [UnimplementedError] is thrown.
class MockWebAuthnCredentialPlatform implements WebAuthnCredentialPlatform {
  /// Creates a [MockWebAuthnCredentialPlatform] with optional callbacks.
  MockWebAuthnCredentialPlatform({
    Future<String> Function(String)? createCredential,
    Future<String> Function(String)? getCredential,
    Future<bool> Function()? isPasskeySupported,
  })  : _createCredential = createCredential,
        _getCredential = getCredential,
        _isPasskeySupported = isPasskeySupported;

  final Future<String> Function(String)? _createCredential;
  final Future<String> Function(String)? _getCredential;
  final Future<bool> Function()? _isPasskeySupported;

  @override
  Future<String> createCredential(String optionsJson) {
    if (_createCredential == null) {
      throw UnimplementedError('createCredential not mocked');
    }
    return _createCredential(optionsJson);
  }

  @override
  Future<String> getCredential(String optionsJson) {
    if (_getCredential == null) {
      throw UnimplementedError('getCredential not mocked');
    }
    return _getCredential(optionsJson);
  }

  @override
  Future<bool> isPasskeySupported() {
    if (_isPasskeySupported == null) {
      throw UnimplementedError('isPasskeySupported not mocked');
    }
    return _isPasskeySupported();
  }
}

/// Test credential assertion response JSON (AuthenticationResponseJSON).
/// Copied from sign_in_webauthn_test.dart -- known to work with Cognito validation.
const testCredentialResponse =
    '{"id":"credential-id",'
    '"rawId":"Y3JlZGVudGlhbC1pZA",'
    '"type":"public-key",'
    '"response":{'
    '"clientDataJSON":"eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0",'
    '"authenticatorData":"SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2MdAAAAAA",'
    '"signature":"MEUCIQDKg7m-jRDKvPIzSaR6SYMBjG3qPLCvkKqz_Ypfhnkm3Q",'
    '"userHandle":"dXNlci1pZA"},'
    '"clientExtensionResults":{}}';

/// Test credential registration response JSON (RegistrationResponseJSON).
/// Used for associateWebAuthnCredential (passkey registration) tests.
const testRegistrationResponse =
    '{"id":"Y3JlZGVudGlhbElk",'
    '"rawId":"Y3JlZGVudGlhbElk",'
    '"type":"public-key",'
    '"response":{'
    '"clientDataJSON":"eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0",'
    '"attestationObject":"o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YQ"},'
    '"clientExtensionResults":{},'
    '"authenticatorAttachment":"platform"}';

/// Creates a [MockWebAuthnCredentialPlatform] that succeeds for both
/// getCredential (sign-in) and createCredential (registration).
MockWebAuthnCredentialPlatform createSuccessMockWebAuthnPlatform() {
  return MockWebAuthnCredentialPlatform(
    getCredential: (_) async => testCredentialResponse,
    createCredential: (_) async => testRegistrationResponse,
    isPasskeySupported: () async => true,
  );
}

/// Creates a [MockWebAuthnCredentialPlatform] that throws
/// [PasskeyCancelledException] when the user cancels.
MockWebAuthnCredentialPlatform createCancelledMockWebAuthnPlatform() {
  return MockWebAuthnCredentialPlatform(
    getCredential: (_) async =>
        throw const PasskeyCancelledException('User cancelled'),
    createCredential: (_) async =>
        throw const PasskeyCancelledException('User cancelled'),
    isPasskeySupported: () async => true,
  );
}

/// Creates a [MockWebAuthnCredentialPlatform] that throws
/// [PasskeyNotSupportedException] for all operations.
MockWebAuthnCredentialPlatform createUnsupportedMockWebAuthnPlatform() {
  return MockWebAuthnCredentialPlatform(
    getCredential: (_) async =>
        throw const PasskeyNotSupportedException('Passkeys not supported'),
    createCredential: (_) async =>
        throw const PasskeyNotSupportedException('Passkeys not supported'),
    isPasskeySupported: () async => false,
  );
}

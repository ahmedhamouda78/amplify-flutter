// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

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

/// Pigeon bridge for WebAuthn/passkey operations.
///
/// Platform implementations (iOS/macOS via ASAuthorizationController,
/// Android via CredentialManager) handle the native ceremony and return
/// JSON-serialized W3C WebAuthn Level 3 response objects.
@HostApi()
abstract class WebAuthnBridgeApi {
  /// Creates a new passkey credential on the device.
  ///
  /// [optionsJson] is a JSON-serialized `PublicKeyCredentialCreationOptions`.
  /// Returns a JSON-serialized `RegistrationResponseJSON`.
  @async
  String createCredential(String optionsJson);

  /// Retrieves a passkey credential assertion for authentication.
  ///
  /// [optionsJson] is a JSON-serialized `PublicKeyCredentialRequestOptions`.
  /// Returns a JSON-serialized `AuthenticationResponseJSON`.
  @async
  String getCredential(String optionsJson);

  /// Returns whether the current device/platform supports passkeys.
  @async
  bool isPasskeySupported();
}

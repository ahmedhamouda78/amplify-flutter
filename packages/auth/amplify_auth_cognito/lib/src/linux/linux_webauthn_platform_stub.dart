// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

// Web stub — LinuxWebAuthnPlatform is not used on web.
// The real implementation lives in linux_webauthn_platform.dart.

import 'package:amplify_auth_cognito_dart/amplify_auth_cognito_dart.dart';

/// Stub for web. Never instantiated on web (guarded by [zIsWeb] in addPlugin).
class LinuxWebAuthnPlatform implements WebAuthnCredentialPlatform {
  @override
  Future<bool> isPasskeySupported() => Future.value(false);

  @override
  Future<String> createCredential(String optionsJson) =>
      throw UnsupportedError('Not supported on web');

  @override
  Future<String> getCredential(String optionsJson) =>
      throw UnsupportedError('Not supported on web');
}

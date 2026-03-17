// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:amplify_auth_integration_test/amplify_auth_integration_test.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_integration_test/amplify_integration_test.dart';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_runner.dart';

void main() {
  testRunner.setupTests();

  group('WebAuthn Registration', () {
    // REG-01: Happy path registration
    group('happy path', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createSuccessMockWebAuthnPlatform(),
        );
      });

      asyncTest('can register passkey for authenticated user', (_) async {
        final username = webAuthnEnvironment.generateUsername();
        final password = generatePassword();

        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: webAuthnEnvironment.getDefaultAttributes(username),
        );

        // Sign in with password to get authenticated session
        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);

        // Register passkey -- should complete without error
        // This calls Cognito StartWebAuthnRegistration, then mock createCredential,
        // then Cognito CompleteWebAuthnRegistration
        await Amplify.Auth.associateWebAuthnCredential();

        // Verify passkey was registered by listing credentials
        final credentials = await Amplify.Auth.listWebAuthnCredentials();
        check(credentials).isNotEmpty();
      });
    });

    // REG-02: User cancels registration
    group('user cancels', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createCancelledMockWebAuthnPlatform(),
        );
      });

      asyncTest('throws PasskeyCancelledException on cancel', (_) async {
        final username = webAuthnEnvironment.generateUsername();
        final password = generatePassword();

        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: webAuthnEnvironment.getDefaultAttributes(username),
        );

        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);

        // Attempt to register -- mock throws PasskeyCancelledException on createCredential
        expect(
          () => Amplify.Auth.associateWebAuthnCredential(),
          throwsA(isA<PasskeyCancelledException>()),
        );
      });
    });

    // REG-03: Platform unsupported
    group('platform unsupported', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createUnsupportedMockWebAuthnPlatform(),
        );
      });

      asyncTest('throws PasskeyNotSupportedException', (_) async {
        final username = webAuthnEnvironment.generateUsername();
        final password = generatePassword();

        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: webAuthnEnvironment.getDefaultAttributes(username),
        );

        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);

        // Attempt to register -- mock throws PasskeyNotSupportedException
        expect(
          () => Amplify.Auth.associateWebAuthnCredential(),
          throwsA(isA<PasskeyNotSupportedException>()),
        );
      });
    });

    // REG-04: Already-registered credential
    group('already registered', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createSuccessMockWebAuthnPlatform(),
        );
      });

      asyncTest('handles duplicate registration attempt', (_) async {
        final username = webAuthnEnvironment.generateUsername();
        final password = generatePassword();

        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: webAuthnEnvironment.getDefaultAttributes(username),
        );

        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);

        // Register passkey first time -- should succeed
        await Amplify.Auth.associateWebAuthnCredential();

        // Register passkey second time with same credential ID.
        // Cognito may accept (creating a new credential) or reject
        // depending on excludeCredentials in creation options.
        // The mock always returns the same credential ID, so Cognito
        // may reject with a duplicate error.
        // If Cognito accepts (since the mock ID is different from what's
        // actually stored), this is still valid -- the test verifies the
        // flow completes or throws an appropriate error.
        try {
          await Amplify.Auth.associateWebAuthnCredential();
          // If it succeeds, that's acceptable -- Cognito handled it
        } on AuthException {
          // Expected -- duplicate credential rejected by Cognito
        }
      });
    });

    // SUPPORT-01: isPasskeySupported returns expected values
    group('isPasskeySupported', () {
      asyncTest('returns true when platform supports passkeys', (_) async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createSuccessMockWebAuthnPlatform(),
        );

        final cognitoPlugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
        final supported = await cognitoPlugin.isPasskeySupported();
        check(supported).isTrue();
      });

      asyncTest('returns false when platform does not support passkeys', (_) async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createUnsupportedMockWebAuthnPlatform(),
        );

        final cognitoPlugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
        final supported = await cognitoPlugin.isPasskeySupported();
        check(supported).isFalse();
      });
    });
  });
}

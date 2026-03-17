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

  group('WebAuthn Sign-In', () {
    // SIGN-IN-01: Happy path - sign in with passkey after registration
    group('happy path', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createSuccessMockWebAuthnPlatform(),
        );
      });

      asyncTest('can sign in with passkey after registration', (_) async {
        final username = webAuthnEnvironment.generateUsername();
        final password = generatePassword();

        // Create user via admin API
        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: webAuthnEnvironment.getDefaultAttributes(username),
        );

        // Sign in with password first to get authenticated session
        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);

        // Register passkey (stub returns instant success)
        await Amplify.Auth.associateWebAuthnCredential();

        // Sign out
        await Amplify.Auth.signOut();

        // Sign in with passkey via USER_AUTH flow
        final passkeySignInRes = await Amplify.Auth.signIn(
          username: username,
          options: const SignInOptions(
            pluginOptions: CognitoSignInPluginOptions(
              authFlowType: AuthenticationFlowType.userAuth,
            ),
          ),
        );
        check(passkeySignInRes.nextStep.signInStep).equals(AuthSignInStep.done);
      });
    });

    // SIGN-IN-02: User cancels during sign-in
    group('user cancels', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: MockWebAuthnCredentialPlatform(
            // createCredential succeeds (for passkey registration setup)
            createCredential: (_) async => testRegistrationResponse,
            // getCredential throws cancelled (for sign-in attempt)
            getCredential: (_) async =>
                throw const PasskeyCancelledException('User cancelled'),
            isPasskeySupported: () async => true,
          ),
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

        // Sign in with password, register passkey
        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);
        await Amplify.Auth.associateWebAuthnCredential();
        await Amplify.Auth.signOut();

        // Attempt passkey sign-in -- mock throws on getCredential
        await expectLater(
          Amplify.Auth.signIn(
            username: username,
            options: const SignInOptions(
              pluginOptions: CognitoSignInPluginOptions(
                authFlowType: AuthenticationFlowType.userAuth,
              ),
            ),
          ),
          throwsA(isA<PasskeyCancelledException>()),
        );
      });
    });

    // SIGN-IN-03: Platform not supported
    group('passkey not supported', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: MockWebAuthnCredentialPlatform(
            createCredential: (_) async => testRegistrationResponse,
            getCredential: (_) async =>
                throw const PasskeyNotSupportedException('Not supported'),
            isPasskeySupported: () async => false,
          ),
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
        await Amplify.Auth.associateWebAuthnCredential();
        await Amplify.Auth.signOut();

        await expectLater(
          Amplify.Auth.signIn(
            username: username,
            options: const SignInOptions(
              pluginOptions: CognitoSignInPluginOptions(
                authFlowType: AuthenticationFlowType.userAuth,
              ),
            ),
          ),
          throwsA(isA<PasskeyNotSupportedException>()),
        );
      });
    });

    // SIGN-IN-04: Invalid credential response
    group('invalid credential', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: MockWebAuthnCredentialPlatform(
            createCredential: (_) async => testRegistrationResponse,
            getCredential: (_) async => '{"invalid": "json"}', // malformed
            isPasskeySupported: () async => true,
          ),
        );
      });

      asyncTest('throws on invalid credential response', (_) async {
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
        await Amplify.Auth.associateWebAuthnCredential();
        await Amplify.Auth.signOut();

        await expectLater(
          Amplify.Auth.signIn(
            username: username,
            options: const SignInOptions(
              pluginOptions: CognitoSignInPluginOptions(
                authFlowType: AuthenticationFlowType.userAuth,
              ),
            ),
          ),
          throwsA(isA<AuthException>()),
        );
      });
    });

    // SELECT-01: First-factor selection when user has password + passkey
    group('first-factor selection', () {
      setUp(() async {
        await testRunner.configure(
          environmentName: 'webauthn',
          useAmplifyOutputs: true,
          webAuthnPlatform: createSuccessMockWebAuthnPlatform(),
        );
      });

      asyncTest('handles SELECT_CHALLENGE with password and passkey', (_) async {
        final username = webAuthnEnvironment.generateUsername();
        final password = generatePassword();
        await adminCreateUser(
          username,
          password,
          autoConfirm: true,
          verifyAttributes: true,
          attributes: webAuthnEnvironment.getDefaultAttributes(username),
        );

        // Sign in with password first, register passkey
        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        check(signInRes.nextStep.signInStep).equals(AuthSignInStep.done);
        await Amplify.Auth.associateWebAuthnCredential();
        await Amplify.Auth.signOut();

        // Sign in with USER_AUTH flow -- Cognito may issue SELECT_CHALLENGE
        // if preferredChallenge is WEB_AUTHN but user has multiple factors.
        final passkeySignInRes = await Amplify.Auth.signIn(
          username: username,
          options: const SignInOptions(
            pluginOptions: CognitoSignInPluginOptions(
              authFlowType: AuthenticationFlowType.userAuth,
            ),
          ),
        );

        final step = passkeySignInRes.nextStep.signInStep;
        if (step == AuthSignInStep.continueSignInWithFirstFactorSelection) {
          // User must select a factor -- choose WEB_AUTHN
          final confirmRes = await Amplify.Auth.confirmSignIn(
            confirmationValue: 'WEB_AUTHN',
          );
          check(confirmRes.nextStep.signInStep).equals(AuthSignInStep.done);
        } else {
          // Direct passkey sign-in (preferred challenge skipped selection)
          check(step).equals(AuthSignInStep.done);
        }
      });
    });
  });
}

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:amplify_flutter/amplify_flutter.dart';

/// Controls whether passkey registration prompts are shown.
enum PasskeyPromptBehavior {
  /// Always prompt for passkey registration.
  always,

  /// Never prompt for passkey registration.
  never,
}

/// Configuration for when passkey registration prompts are displayed.
class PasskeyRegistrationPrompts {
  /// Creates a [PasskeyRegistrationPrompts] with the given behaviors.
  const PasskeyRegistrationPrompts({
    this.afterSignIn = PasskeyPromptBehavior.always,
    this.afterSignUp = PasskeyPromptBehavior.always,
  });

  /// Prompts are enabled after both sign-in and sign-up.
  const PasskeyRegistrationPrompts.enabled()
    : afterSignIn = PasskeyPromptBehavior.always,
      afterSignUp = PasskeyPromptBehavior.always;

  /// Prompts are disabled after both sign-in and sign-up.
  const PasskeyRegistrationPrompts.disabled()
    : afterSignIn = PasskeyPromptBehavior.never,
      afterSignUp = PasskeyPromptBehavior.never;

  /// Whether to prompt for passkey registration after sign-in.
  final PasskeyPromptBehavior afterSignIn;

  /// Whether to prompt for passkey registration after sign-up.
  final PasskeyPromptBehavior afterSignUp;

  /// Whether passkey registration prompt is enabled after sign-in.
  bool get isEnabledAfterSignIn => afterSignIn == PasskeyPromptBehavior.always;

  /// Whether passkey registration prompt is enabled after sign-up.
  bool get isEnabledAfterSignUp => afterSignUp == PasskeyPromptBehavior.always;
}

/// Settings for passwordless authentication in the Authenticator.
class PasswordlessSettings {
  /// Creates [PasswordlessSettings] with the given configuration.
  const PasswordlessSettings({
    this.hiddenAuthMethods,
    this.preferredAuthMethod,
    this.passkeyRegistrationPrompts,
  });

  /// Auth factor types to hide from the first-factor selection screen.
  final List<AuthFactorType>? hiddenAuthMethods;

  /// The preferred auth method to use as a challenge override.
  final AuthFactorType? preferredAuthMethod;

  /// Configuration for post-auth passkey registration prompts.
  final PasskeyRegistrationPrompts? passkeyRegistrationPrompts;
}

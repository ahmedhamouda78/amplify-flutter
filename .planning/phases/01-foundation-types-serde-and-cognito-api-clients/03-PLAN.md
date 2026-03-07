---
wave: 1
depends_on: []
files_modified:
  - packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart
  - packages/amplify_core/lib/src/types/exception/amplify_exception.dart
  - packages/amplify_core/lib/amplify_core.dart
requirements: [AUTH-06]
autonomous: true
---

# Plan 03: PasskeyException Hierarchy

## Objective

Create a typed `PasskeyException` hierarchy extending `AuthException` with specific error codes for passkey operations: not supported, user cancelled, registration failed, assertion failed, and RP mismatch.

## Context

The existing auth exception hierarchy uses sealed classes in `packages/amplify_core/lib/src/types/exception/`. The base `AuthException` is `sealed` and declared as a `part` of `amplify_exception.dart`. All auth exception subtypes follow the same pattern:
- Declared as `part of` the `amplify_exception.dart` library
- Extend `AuthException`
- Include `const` constructors with `super.message`, `super.recoverySuggestion`, `super.underlyingException`
- Override `runtimeTypeName` getter (via `AWSDebuggable` mixin)

The Amplify JS reference uses `PasskeyError` with error codes (see `.planning/research/amplify-js-reference.md` section 7). The native SDKs use `WebAuthnError` (Swift) and `WebAuthnFailedException` + subtypes (Android). See `.planning/research/native-sdk-references.md` section 3.

## Tasks

### Task 1: Create PasskeyException base class and subtypes

**File:** `packages/amplify_core/lib/src/types/exception/auth/passkey_exception.dart`

Create a new file with standard license header, declared as `part of '../amplify_exception.dart';`.

Define the following classes:

**`PasskeyException`** (base class for all passkey errors):
```dart
/// {@template amplify_core.auth.passkey_exception}
/// Exception thrown when a passkey/WebAuthn operation fails.
/// {@endtemplate}
class PasskeyException extends AuthException {
  /// {@macro amplify_core.auth.passkey_exception}
  const PasskeyException(
    super.message, {
    super.recoverySuggestion,
    super.underlyingException,
  });
}
```

**`PasskeyNotSupportedException`** -- thrown when the current device/platform does not support passkeys:
- Default recovery suggestion: `'Passkeys require a compatible device and operating system version.'`

**`PasskeyCancelledException`** -- thrown when the user cancels the passkey ceremony (biometric prompt, etc.):
- This is distinct from `UserCancelledException` which is for general auth cancellation
- Default recovery suggestion: `'The passkey operation was cancelled. Please try again.'`

**`PasskeyRegistrationFailedException`** -- thrown when the platform fails to create a new passkey credential:
- Default recovery suggestion: `'Failed to register passkey. Ensure your device supports passkeys and try again.'`

**`PasskeyAssertionFailedException`** -- thrown when the platform fails to retrieve/assert a passkey credential during sign-in:
- Default recovery suggestion: `'Failed to authenticate with passkey. Ensure you have a registered passkey and try again.'`

**`PasskeyRpMismatchException`** -- thrown when the relying party ID does not match the expected domain:
- Default recovery suggestion: `'The relying party ID does not match the application domain. Check your Cognito user pool configuration.'`

Each subtype should:
- Extend `PasskeyException`
- Have a `const` constructor with `super.message` and optional `super.recoverySuggestion`, `super.underlyingException`
- Have a dartdoc `{@template}` / `{@endtemplate}` block
- Not override `runtimeTypeName` (inherited from `AWSDebuggable` via `AuthException`)

### Task 2: Register as part of amplify_exception library

**File:** `packages/amplify_core/lib/src/types/exception/amplify_exception.dart`

Add a `part` directive for the new file. Insert after the existing auth exception parts (after line 19, `part 'auth/validation_exception.dart';`):
```dart
part 'auth/passkey_exception.dart';
```

### Task 3: Export from amplify_core barrel

**File:** `packages/amplify_core/lib/amplify_core.dart`

Verify that the exception types are already exported transitively through the `amplify_exception.dart` export. Since `amplify_exception.dart` uses `part` files, all classes in `passkey_exception.dart` will be automatically available through the existing export of `amplify_exception.dart`. No explicit new export line should be needed, but verify this.

If the barrel file explicitly exports individual exception files (rather than the library), add:
```dart
export 'src/types/exception/auth/passkey_exception.dart';
```

## Verification

1. `dart analyze packages/amplify_core` -- no errors
2. `PasskeyException` is a subtype of `AuthException` (passes `is AuthException` check)
3. All five subtypes compile and are accessible from `package:amplify_core/amplify_core.dart`
4. The subtypes can be used in catch blocks: `on PasskeyNotSupportedException catch (e) { ... }`
5. Each exception type can be constructed with `const` constructor
6. The sealed class hierarchy of `AuthException` still works (exhaustive pattern matching in switch statements still compiles)

## must_haves

- [ ] `PasskeyException` extends `AuthException`
- [ ] `PasskeyNotSupportedException` extends `PasskeyException`
- [ ] `PasskeyCancelledException` extends `PasskeyException`
- [ ] `PasskeyRegistrationFailedException` extends `PasskeyException`
- [ ] `PasskeyAssertionFailedException` extends `PasskeyException`
- [ ] `PasskeyRpMismatchException` extends `PasskeyException`
- [ ] All exception types are accessible from `package:amplify_core/amplify_core.dart`
- [ ] All exception types have `const` constructors with `message`, optional `recoverySuggestion`, optional `underlyingException`
- [ ] No regressions in existing exception handling code

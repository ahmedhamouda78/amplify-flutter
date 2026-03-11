# Native SDK Passkey Implementation Reference

**Researched:** 2026-03-07
**Overall confidence:** HIGH (verified from GitHub source code, PR analysis, release notes, official documentation)
**Sources:** amplify-swift v2.45.0 (PR #3920), amplify-android v2.25.0 (PR #2952)

## Executive Summary

Both amplify-swift and amplify-android shipped passkey/WebAuthn support in November 2024 as part of AWS Cognito's passwordless authentication launch. Both implementations follow an identical architectural pattern: a **state machine** with WebAuthn-specific states and events, **action handlers** that orchestrate Cognito API calls and platform WebAuthn ceremonies, and **use case / task classes** for credential management (register, list, delete). The key difference is the platform WebAuthn bridge: Swift uses `ASAuthorizationController` with `ASAuthorizationPlatformPublicKeyCredentialProvider`, while Android uses `androidx.credentials.CredentialManager`.

For amplify-flutter, the critical insight is that both native SDKs use **method channel-style platform bridges** -- they delegate the actual WebAuthn ceremony to platform-specific code while keeping all Cognito API logic in the shared layer. Flutter should follow the same pattern: Cognito flow logic in Dart, with platform channels to iOS `ASAuthorizationController` and Android `CredentialManager` for the WebAuthn ceremonies.

---

## 1. amplify-swift Implementation

### Release Info

- **Version:** 2.45.0 (November 25, 2024)
- **PR:** [#3920](https://github.com/aws-amplify/amplify-swift/pull/3920) - "add passwordless support"
- **Author:** @harsh62
- **Scope:** 36 commits, 73+ unit tests, integration tests

### File Structure

The WebAuthn implementation is organized under `AmplifyPlugins/Auth/Sources/AWSCognitoAuthPlugin/`:

```
Actions/SignIn/WebAuthn/
  AssertWebAuthnCredentials.swift       # Sign-in assertion action
  FetchCredentialOptions.swift          # Fetches credential options from Cognito
  InitializeWebAuthn.swift              # Initializes WebAuthn flow
  PlatformWebAuthnCredentials.swift     # Apple ASAuthorization bridge (KEY FILE)
  VerifyWebAuthnCredential.swift        # Sends credential to Cognito for verification

StateMachine/CodeGen/
  Data/WebAuthnSignInData.swift         # Data context for WebAuthn sign-in
  Errors/WebAuthnError.swift            # Error types
  Events/WebAuthnEvent.swift            # State machine events
  States/WebAuthnSignInState.swift      # State machine states
  Resolvers/SignIn/WebAuthnSignInState+Resolver.swift  # State transitions

Task/
  AssociateWebAuthnCredentialTask.swift  # Registration use case
  DeleteWebAuthnCredentialTask.swift     # Deletion use case
  ListWebAuthnCredentialsTask.swift      # Listing use case
  Models/AWSWebAuthCredentialsModels.swift

Client Behavior/
  AWSCognitoAuthPlugin+WebAuthnBehaviour.swift  # Plugin conformance

Public API (in Amplify/Categories/Auth/):
  AuthCategoryWebAuthnBehaviour.swift    # Public protocol
  AuthCategory+WebAuthnBehaviour.swift   # Category extension
  AuthWebAuthnCredential.swift           # Public credential type
```

### Platform Bridge: `PlatformWebAuthnCredentials.swift`

This is the most important file for Flutter reference. It bridges Apple's `AuthenticationServices` framework with Amplify's WebAuthn flow.

**Platform Requirements:** iOS 17.4+, macOS 13.5+, visionOS 1.0+

**Key Components:**

1. **Protocols for dependency injection:**
   - `WebAuthnCredentialsProtocol` -- base protocol with presentation anchor
   - `CredentialRegistrantProtocol` -- handles `navigator.credentials.create()` equivalent
   - `CredentialAsserterProtocol` -- handles `navigator.credentials.get()` equivalent

2. **`PlatformWebAuthnCredentials` class** implements both protocols:
   - Uses `ASAuthorizationPlatformPublicKeyCredentialProvider` for passkey operations
   - Uses `ASAuthorizationController` to present the system passkey UI
   - Bridges async/await with `ASAuthorizationControllerDelegate` via `CheckedContinuation`
   - Implements `ASAuthorizationControllerPresentationContextProviding` for UI anchoring

3. **Registration flow:**
   - Receives `CredentialCreationOptions` (from Cognito's `StartWebAuthnRegistration`)
   - Creates `ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest`
   - Presents via `ASAuthorizationController`
   - Returns `CredentialRegistrationPayload` on delegate callback

4. **Assertion flow (sign-in):**
   - Receives `CredentialAssertionOptions` (from Cognito's `CREDENTIAL_REQUEST_OPTIONS`)
   - Creates `ASAuthorizationPlatformPublicKeyCredentialAssertionRequest`
   - Presents via `ASAuthorizationController`
   - Returns `CredentialAssertionPayload` on delegate callback

5. **Error mapping:**
   - `ASAuthorizationError` -> `WebAuthnError.assertionFailed` or `.creationFailed`
   - Generic errors -> `WebAuthnError.unknown`

### State Machine: WebAuthn Sign-In States

```
notStarted
  -> fetchingCredentialOptions    (on InitiateWebAuthnSignIn)
  -> assertingCredentials         (on AssertCredentialOptions, for SELECT_CHALLENGE shortcut)
fetchingCredentialOptions
  -> assertingCredentials         (on AssertCredentials)
assertingCredentials
  -> verifyingCredentialsAndSigningIn  (on VerifyCredentialsAndSignIn)
verifyingCredentialsAndSigningIn
  -> signedIn(SignedInData)       (on SignedIn)
error(SignInError)
  -> notStarted                   (on InitiateWebAuthnSignIn, retry)
```

### Public API Surface

```swift
// Protocol: AuthCategoryWebAuthnBehaviour

// Register a passkey (post-auth, requires signed-in user)
func associateWebAuthnCredential(
    presentationAnchor: AuthUIPresentationAnchor?,  // iOS/macOS
    options: AuthAssociateWebAuthnCredentialRequest.Options?
) async throws

// List registered passkeys
func listWebAuthnCredentials(
    options: AuthListWebAuthnCredentialsRequest.Options?
) async throws -> AuthListWebAuthnCredentialsResult

// Delete a passkey
func deleteWebAuthnCredential(
    credentialId: String,
    options: AuthDeleteWebAuthnCredentialRequest.Options?
) async throws

// Sign-in with passkey (via existing signIn API)
func signIn(
    username: String?,
    password: String?,
    options: AuthSignInRequest.Options(
        presentationAnchorForWebAuthn: AuthUIPresentationAnchor?
    )
) async throws -> AuthSignInResult
```

**Key design choice:** The `presentationAnchor` parameter is platform-specific. On iOS/macOS, the `ASAuthorizationController` needs a window anchor to present the passkey UI. On visionOS, this is required (not optional).

### WebAuthn Error Types

```swift
enum WebAuthnError: Equatable {
    case assertionFailed(ASAuthorizationError)  // Sign-in platform error
    case creationFailed(ASAuthorizationError)   // Registration platform error
    case service(AuthErrorConvertible)          // Cognito service error
    case unknown(String, Error?)                // Catch-all
}
```

---

## 2. amplify-android Implementation

### Release Info

- **Version:** 2.25.0 (November 27, 2024)
- **PR:** [#2952](https://github.com/aws-amplify/amplify-android/pull/2952) - "Add Passwordless features to Amplify"
- **Author:** @mattcreaser
- **Reviewers:** @vincetran, @edisooon, @sktimalsina

### File Structure

Organized under `aws-auth-cognito/src/main/java/com/amplifyframework/auth/cognito/`:

```
helpers/
  WebAuthnHelper.kt                     # CredentialManager bridge (KEY FILE)

actions/
  WebAuthnSignInCognitoActions.kt        # State machine action implementations

usecases/
  AssociateWebAuthnCredentialUseCase.kt   # Registration use case
  DeleteWebAuthnCredentialUseCase.kt      # Deletion use case
  ListWebAuthnCredentialsUseCase.kt       # Listing use case

exceptions/webauthn/
  WebAuthnFailedException.kt
  WebAuthnCredentialAlreadyExistsException.kt
  WebAuthnNotSupportedException.kt
  WebAuthnRpMismatchException.kt

options/
  AWSCognitoAuthListWebAuthnCredentialsOptions.kt

result/
  AWSCognitoAuthListWebAuthnCredentialsResult.kt

statemachine/codegen/
  states/WebAuthnSignInState.kt          # State machine states
  events/WebAuthnEvent.kt               # State machine events
  data/WebAuthnSignInContext.kt          # Data context
  actions/WebAuthnSignInActions.kt       # Action interface
```

Core framework types (in `core/src/main/java/com/amplifyframework/auth/`):

```
options/
  AuthAssociateWebAuthnCredentialsOptions.kt
  AuthDeleteWebAuthnCredentialOptions.kt
  AuthListWebAuthnCredentialsOptions.kt

result/
  AuthListWebAuthnCredentialsResult.kt
```

### Platform Bridge: `WebAuthnHelper.kt`

**Platform Requirements:** Android 9 (API level 28)+, requires Google Play Services

**Key Components:**

1. **`CredentialManager` wrapper:**
   - Uses `androidx.credentials.CredentialManager` for both registration and assertion
   - Takes an `Activity` reference (weak) for proper UI presentation context
   - Falls back to `Application` context if no Activity available (launches in separate Task)

2. **`getCredential()` method (sign-in assertion):**
   - Creates `GetCredentialRequest` with `GetPublicKeyCredentialOption`
   - Passes JSON string from Cognito's `CREDENTIAL_REQUEST_OPTIONS`
   - Calls `credentialManager.getCredential(context, request)`
   - Returns response JSON string

3. **`createCredential()` method (registration):**
   - Creates `CreatePublicKeyCredentialRequest` from Cognito's options JSON
   - Calls `credentialManager.createCredential(context, request)`
   - Returns response JSON string
   - Requires API 28+

4. **Error mapping:**
   - `GetCredentialCancellationException` -> `UserCancelledException`
   - `CreateCredentialCancellationException` -> `UserCancelledException`
   - Credential already exists -> `WebAuthnCredentialAlreadyExistsException`
   - Provider not found -> `WebAuthnNotSupportedException`
   - Domain mismatch -> `WebAuthnRpMismatchException`
   - Other errors -> `WebAuthnFailedException`

5. **Context management:**
   - Uses `WeakReference<Activity>` to avoid memory leaks
   - Warns when Activity context unavailable (UX degradation: separate Task)

### State Machine: WebAuthn Sign-In States

```kotlin
sealed class WebAuthnSignInState {
    class NotStarted : WebAuthnSignInState()
    class FetchingCredentialOptions : WebAuthnSignInState()
    class AssertingCredentials : WebAuthnSignInState()
    class VerifyingCredentialsAndSigningIn : WebAuthnSignInState()
    class SignedIn : WebAuthnSignInState()
    class Error(val exception: Exception, val context: WebAuthnSignInContext) : WebAuthnSignInState()
}
```

**State transitions mirror Swift exactly:**
- `NotStarted` -> `FetchingCredentialOptions` or `AssertingCredentials`
- `FetchingCredentialOptions` -> `AssertingCredentials`
- `AssertingCredentials` -> `VerifyingCredentialsAndSigningIn`
- `VerifyingCredentialsAndSigningIn` -> `SignedIn`
- Any state -> `Error` on exception
- `Error` -> `NotStarted` on retry

### State Machine Actions: `WebAuthnSignInCognitoActions.kt`

Three key actions:

1. **`fetchCredentialOptions()`** -- Responds to `SELECT_CHALLENGE` with `ANSWER: "WEB_AUTHN"` to get `CREDENTIAL_REQUEST_OPTIONS`
2. **`assertCredentials()`** -- Uses `WebAuthnHelper.getCredential()` with the calling Activity and credential options JSON
3. **`verifyCredentialAndSignIn()`** -- Sends the credential response JSON back to Cognito via `RespondToAuthChallenge`

### WebAuthn Sign-In Context

```kotlin
data class WebAuthnSignInContext(
    val username: String,
    val callingActivity: WeakReference<Activity>?,  // For CredentialManager UI
    val session: String,                             // Cognito session token
    val requestJson: String?,                        // CREDENTIAL_REQUEST_OPTIONS JSON
    val responseJson: String?                        // Credential assertion response JSON
) {
    override fun toString(): String {
        // Masks sensitive fields (session, JSON) in logs
    }
}
```

### Registration Use Case: `AssociateWebAuthnCredentialUseCase.kt`

Three-step process:

1. **`getCredentialRequestJson()`** -- Calls Cognito `StartWebAuthnRegistration` with access token
2. **`WebAuthnHelper.createCredential()`** -- Delegates to CredentialManager for device registration
3. **`associateCredential()`** -- Calls Cognito `CompleteWebAuthnRegistration` with the response

### Public API Surface (Android)

```java
// AuthCategoryBehavior interface

// Register a passkey (post-auth, requires Activity)
void associateWebAuthnCredential(
    Activity callingActivity,
    Action onSuccess,
    Consumer<AuthException> onError
);

// List registered passkeys
void listWebAuthnCredentials(
    Consumer<AuthListWebAuthnCredentialsResult> onSuccess,
    Consumer<AuthException> onError
);

// Delete a passkey
void deleteWebAuthnCredential(
    String credentialId,
    Action onSuccess,
    Consumer<AuthException> onError
);

// Sign-in (existing API, callingActivity option added)
void signIn(
    String username,
    String password,
    AuthSignInOptions options,  // includes callingActivity for passkey UI
    Consumer<AuthSignInResult> onSuccess,
    Consumer<AuthException> onError
);
```

**Key design choice:** Android requires an `Activity` reference to attach the passkey UI to the correct Task. The `callingActivity` is passed via sign-in options, not as a top-level parameter.

### Android-Specific Requirements

- **Digital Asset Links:** A `/.well-known/assetlinks.json` file must be deployed to the RP domain granting `get_login_creds` permission to the app's signing certificate
- **Google Play Services:** Required for `CredentialManager` to function
- **API level 28+:** Required for passkey registration (lower levels cannot register but may be able to use cross-platform authenticators)

### WebAuthn Exception Types

```kotlin
WebAuthnFailedException          // Generic passkey operation failure
WebAuthnCredentialAlreadyExistsException  // Credential already registered
WebAuthnNotSupportedException    // Device/provider doesn't support passkeys
WebAuthnRpMismatchException      // RP ID doesn't match app domain
```

---

## 3. Common Patterns (Both SDKs)

### Shared Architecture

Both SDKs follow an identical high-level architecture:

```
                    +------------------+
                    | Public API       |
                    | (signIn,         |
                    |  associateWebAuthnCredential, |
                    |  listWebAuthn,   |
                    |  deleteWebAuthn) |
                    +--------+---------+
                             |
                    +--------+---------+
                    | State Machine    |
                    | (WebAuthnSignIn- |
                    |  State/Events/   |
                    |  Resolver)       |
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
    +---------+---------+       +-----------+-----------+
    | Cognito API       |       | Platform WebAuthn     |
    | (InitiateAuth,    |       | Bridge                |
    |  RespondToAuth-   |       | (ASAuthorization on   |
    |  Challenge,       |       |  iOS; CredentialMgr   |
    |  StartWebAuthn-   |       |  on Android)          |
    |  Registration,    |       +-----------------------+
    |  CompleteWebAuthn-|
    |  Registration)    |
    +-------------------+
```

### Identical State Machine Flow

Both SDKs implement the **exact same state machine** with identical states and transitions:

| State | Description |
|-------|-------------|
| `NotStarted` | Initial state |
| `FetchingCredentialOptions` | Calling Cognito to get `CREDENTIAL_REQUEST_OPTIONS` |
| `AssertingCredentials` | Platform WebAuthn ceremony in progress |
| `VerifyingCredentialsAndSigningIn` | Sending credential to Cognito for verification |
| `SignedIn` | Terminal success state |
| `Error` | Terminal error state (can retry -> NotStarted) |

### Identical Event Types

| Event | Trigger |
|-------|---------|
| `FetchCredentialOptions` | Start WebAuthn flow or respond to SELECT_CHALLENGE |
| `AssertCredentialOptions` | Credential options received, start platform ceremony |
| `VerifyCredentialsAndSignIn` | Platform ceremony complete, verify with Cognito |
| `SignedIn` | Cognito returned tokens |
| `Error/ThrowError` | Any step failed |

### Identical Registration Flow

Both SDKs follow a 3-step registration process:
1. `StartWebAuthnRegistration` (Cognito API) -> get creation options
2. Platform WebAuthn ceremony (create credential on device)
3. `CompleteWebAuthnRegistration` (Cognito API) -> send credential to Cognito

### Identical Credential Management APIs

Both SDKs expose three credential management methods:
- `associateWebAuthnCredential` -- Register a new passkey
- `listWebAuthnCredentials` -- List registered passkeys (paginated)
- `deleteWebAuthnCredential` -- Remove a passkey by credential ID

### Platform Availability Checks

| Platform | Check | Notes |
|----------|-------|-------|
| iOS | `#available(iOS 17.4, macOS 13.5, visionOS 1.0, *)` | Compile-time availability check |
| Android | API level 28+ check, CredentialManager availability | Runtime check via try/catch |

Neither SDK has an explicit `isPasskeySupported()` public API. Instead:
- Swift uses `@available` annotations and platform compilation guards
- Android catches `WebAuthnNotSupportedException` at runtime when CredentialManager is unavailable

### Presentation Context Pattern

Both SDKs require a "presentation anchor" for the passkey UI:
- **iOS:** `AuthUIPresentationAnchor` (a window reference) for `ASAuthorizationController`
- **Android:** `Activity` reference for `CredentialManager` context

This is the most significant platform-specific concern for Flutter, because Flutter apps have:
- A single `FlutterActivity` on Android (accessible via method channel)
- A `UIWindow` on iOS (accessible via method channel)

### Error Handling Pattern

Both SDKs map platform-specific errors to SDK-specific exception types:

| Error Category | Swift | Android |
|---------------|-------|---------|
| User cancelled | `ASAuthorizationError.canceled` | `UserCancelledException` |
| Not supported | (availability check prevents this) | `WebAuthnNotSupportedException` |
| Credential exists | (handled by platform) | `WebAuthnCredentialAlreadyExistsException` |
| Domain mismatch | (handled by platform) | `WebAuthnRpMismatchException` |
| Generic failure | `WebAuthnError.unknown` | `WebAuthnFailedException` |
| Service error | `WebAuthnError.service` | Standard `AuthException` |

---

## 4. Implications for amplify-flutter

### What Flutter Should Replicate

1. **State machine integration:** Add `WebAuthnSignInState` as a sub-state machine within the existing sign-in state machine (both native SDKs do this)

2. **Three credential management APIs:** `associateWebAuthnCredential`, `listWebAuthnCredentials`, `deleteWebAuthnCredential` -- following the same signatures

3. **Platform channel bridge:** Create a method channel that:
   - On iOS: Wraps `ASAuthorizationController` + `ASAuthorizationPlatformPublicKeyCredentialProvider`
   - On Android: Wraps `androidx.credentials.CredentialManager`
   - Accepts JSON-serialized WebAuthn options, returns JSON-serialized WebAuthn responses

4. **Error mapping:** Map platform exceptions to Amplify `AuthException` subtypes

### What Flutter Should Do Differently

1. **Dart-first Cognito logic:** Unlike Swift/Android where Cognito API calls are in Swift/Kotlin, Flutter should keep ALL Cognito API logic in Dart (the existing `amplify_auth_cognito_dart` package). Only the platform WebAuthn ceremony crosses the method channel boundary.

2. **Method channel interface should be minimal:**
   ```
   createCredential(String optionsJson) -> String responseJson
   getCredential(String optionsJson) -> String responseJson
   isPasskeySupported() -> bool  (Flutter should add this, even though native SDKs don't)
   ```

3. **No Activity/Window passing:** Flutter's method channels automatically run in the context of the FlutterActivity/UIViewController, so the platform bridge code can access the Activity/Window directly without passing it across the channel.

4. **Web support via dart:js_interop:** Flutter web can call `navigator.credentials.create()` / `navigator.credentials.get()` directly through JS interop, no method channel needed. This parallels how amplify-js works.

### Key Data Flow for Flutter

```
Dart (amplify_auth_cognito_dart)           Platform Channel        Native (iOS/Android)
================================           ================        ====================
signIn(USER_AUTH, preferredChallenge: WEB_AUTHN)
  -> InitiateAuth to Cognito
  <- CREDENTIAL_REQUEST_OPTIONS
  ------ getCredential(optionsJson) ------>
                                            iOS: ASAuthorizationController
                                            Android: CredentialManager
  <----- responseJson --------------------
  -> RespondToAuthChallenge(CREDENTIAL: responseJson)
  <- AuthenticationResult (tokens)

associateWebAuthnCredential()
  -> StartWebAuthnRegistration (access token)
  <- CredentialCreationOptions
  ------ createCredential(optionsJson) --->
                                            iOS: ASAuthorizationController
                                            Android: CredentialManager
  <----- responseJson --------------------
  -> CompleteWebAuthnRegistration (credential JSON)
  <- Success
```

### Existing Flutter Codebase State

Based on analysis of the codebase (as of PR #6538 merge):

**Already implemented:**
- `USER_AUTH` auth flow type
- `SELECT_CHALLENGE` challenge handling
- `SMS_OTP` and `EMAIL_OTP` challenge handling
- `AuthFactorType` enum with `emailOtp`, `smsOtp` values
- `availableChallenges` field parsing from `InitiateAuth` response
- `createSelectFirstFactorRequest` for SELECT_CHALLENGE responses
- Auto sign-in flow

**Not yet implemented (confirmed by TODO in code):**
- `AuthFactorType.webAuthn` -- commented out with TODO reference
- `WEB_AUTHN` challenge handling in sign-in state machine
- `CREDENTIAL_REQUEST_OPTIONS` parsing
- Platform WebAuthn bridge (method channel)
- `StartWebAuthnRegistration` / `CompleteWebAuthnRegistration` Cognito API calls
- `ListWebAuthnCredentials` / `DeleteWebAuthnCredential` Cognito API calls
- `associateWebAuthnCredential` public API
- `listWebAuthnCredentials` public API
- `deleteWebAuthnCredential` public API

---

## 5. Platform Version Requirements

| Platform | Minimum for Passkeys | Native SDK Version |
|----------|---------------------|-------------------|
| iOS | 17.4 | amplify-swift 2.45.0+ |
| macOS | 13.5 | amplify-swift 2.45.0+ |
| visionOS | 1.0 | amplify-swift 2.45.0+ |
| Android | API 28 (Android 9) | amplify-android 2.25.0+ |
| Web | All modern browsers | (via JS interop) |

**Flutter implications:** The method channel implementation must handle the case where the platform does not support passkeys. Both native SDKs handle this gracefully:
- Swift: Compile-time `@available` checks prevent calling unsupported APIs
- Android: Runtime exception catching with `WebAuthnNotSupportedException`

Flutter should use a runtime check (`isPasskeySupported()`) since method channels can't use compile-time availability.

---

## 6. Digital Asset Links / Associated Domains

### Android: Digital Asset Links

Required file at `https://<RP_DOMAIN>/.well-known/assetlinks.json`:

```json
[{
  "relation": ["delegate_permission/common.get_login_creds"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.app",
    "sha256_cert_fingerprints": ["..."]
  }
}]
```

### iOS: Associated Domains

Requires the `webcredentials:<RP_DOMAIN>` associated domain entitlement in the app's entitlements file, plus an `apple-app-site-association` file on the server.

### Flutter Impact

These are app-level configuration requirements, not SDK implementation concerns. The Flutter SDK documentation should clearly explain both requirements. The amplify CLI / Gen 2 setup should ideally assist with generating these files.

---

## Sources

- [amplify-swift v2.45.0 release](https://github.com/aws-amplify/amplify-swift/releases/tag/2.45.0)
- [amplify-swift PR #3920 - add passwordless support](https://github.com/aws-amplify/amplify-swift/pull/3920)
- [amplify-android v2.25.0 release](https://github.com/aws-amplify/amplify-android/releases/tag/release_v2.25.0)
- [amplify-android PR #2952 - Add Passwordless features to Amplify](https://github.com/aws-amplify/amplify-android/pull/2952)
- [amplify-swift CHANGELOG.md](https://github.com/aws-amplify/amplify-swift/blob/main/CHANGELOG.md)
- [amplify-android CHANGELOG.md](https://github.com/aws-amplify/amplify-android/blob/main/CHANGELOG.md)
- [Amplify Swift WebAuthn credential management docs](https://docs.amplify.aws/swift/build-a-backend/auth/manage-users/manage-webauthn-credentials/)
- [Amplify Android WebAuthn credential management docs](https://docs.amplify.aws/android/build-a-backend/auth/manage-users/manage-webauthn-credentials/)
- [Amplify Swift passwordless docs](https://docs.amplify.aws/swift/build-a-backend/auth/concepts/passwordless/)
- [Amplify Android passwordless docs](https://docs.amplify.aws/android/build-a-backend/auth/concepts/passwordless/)
- [AWS announcement: passwordless authentication with Cognito](https://aws.amazon.com/about-aws/whats-new/2024/11/aws-amplify-passwordless-authentication-amazon-cognito/)
- [amplify-flutter issue #6094 - Passwordless Support](https://github.com/aws-amplify/amplify-flutter/issues/6094)
- [amplify-flutter issue #5788 - Passkey login not supporting in Authenticator UI](https://github.com/aws-amplify/amplify-flutter/issues/5788)
- [amplify-flutter PR #6538 - feat(auth): Passwordless login](https://github.com/aws-amplify/amplify-flutter/pull/6538)
- [amplify-flutter PR #6632 - fix(auth): handle SMS_OTP challenge in USER_AUTH flow](https://github.com/aws-amplify/amplify-flutter/pull/6632)

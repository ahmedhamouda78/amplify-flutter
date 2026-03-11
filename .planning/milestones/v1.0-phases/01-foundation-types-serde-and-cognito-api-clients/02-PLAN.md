---
wave: 1
depends_on: []
files_modified:
  - packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/passkey_types.dart
  - packages/auth/amplify_auth_cognito_dart/lib/src/util/base64url_encode.dart
  - packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart
requirements: [FLOW-05]
autonomous: true
---

# Plan 02: WebAuthn JSON Serialization Types and Base64URL Utilities

## Objective

Define the Dart types for WebAuthn JSON data exchange between Cognito and platform bridges, plus base64url encode/decode utilities. These types serve as the serialization boundary between Cognito API responses (JSON with base64url strings) and platform bridge inputs/outputs (JSON strings passed over method channels).

## Context

Cognito sends/expects JSON following W3C WebAuthn Level 3 spec dictionaries. All binary fields (challenge, credential IDs, authenticator data, etc.) are encoded as base64url strings. The Amplify JS reference implementation defines equivalent types in `types/shared.ts` (see `.planning/research/amplify-js-reference.md` section 6).

## Tasks

### Task 1: Create base64url utility functions

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/util/base64url_encode.dart`

Create a utility file with standard license header containing:
- `String base64UrlEncode(List<int> bytes)` -- Encodes bytes to base64url string without padding. Use `dart:convert` `base64Url` codec, then strip trailing `=` characters.
- `List<int> base64UrlDecode(String encoded)` -- Decodes base64url string to bytes. Normalize padding by appending `=` characters as needed (string length must be multiple of 4), then decode with `base64Url` codec.

### Task 2: Create WebAuthn JSON model types

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/passkey_types.dart`

Create the directory `packages/auth/amplify_auth_cognito_dart/lib/src/model/webauthn/` if it does not exist. Define immutable data classes for WebAuthn JSON exchange. All classes should have:
- Standard license header
- `const` constructors
- `factory .fromJson(Map<String, dynamic>)` constructors
- `Map<String, dynamic> toJson()` methods
- Dartdoc comments on all public members (enforced by `public_member_api_docs` lint)

#### Types to define (10 classes):

**`PasskeyCredentialDescriptor`** (shared sub-type for `excludeCredentials` and `allowCredentials`):
- `String id` (base64url credential ID)
- `String type` (always `'public-key'`)
- `List<String>? transports`

**`PasskeyRpEntity`** (relying party):
- `String id`
- `String name`

**`PasskeyUserEntity`** (user):
- `String id` (base64url user ID)
- `String name`
- `String displayName`

**`PasskeyAuthenticatorSelection`** (authenticator selection criteria):
- `bool? requireResidentKey`
- `String? residentKey`
- `String? userVerification`
- `String? authenticatorAttachment`

**`PasskeyPubKeyCredParam`** (public key credential parameter):
- `String type` (always `'public-key'`)
- `int alg` (e.g. -7 for ES256, -257 for RS256)

**`PasskeyCreateOptions`** (from Cognito's `StartWebAuthnRegistration` response / `CredentialCreationOptions`):
- `String challenge` (base64url)
- `PasskeyRpEntity rp`
- `PasskeyUserEntity user`
- `List<PasskeyPubKeyCredParam> pubKeyCredParams`
- `int? timeout`
- `List<PasskeyCredentialDescriptor>? excludeCredentials`
- `PasskeyAuthenticatorSelection? authenticatorSelection`
- `String? attestation`

**`PasskeyAttestationResponse`** (sub-type of create result):
- `String clientDataJSON` (base64url)
- `String attestationObject` (base64url)
- `String? authenticatorData` (base64url, optional)
- `String? publicKey` (base64url, optional)
- `int? publicKeyAlgorithm`
- `List<String>? transports`

**`PasskeyCreateResult`** (RegistrationResponseJSON, sent to Cognito's `CompleteWebAuthnRegistration`):
- `String id` (base64url credential ID)
- `String rawId` (base64url credential ID)
- `String type` (`'public-key'`)
- `PasskeyAttestationResponse response`
- `Map<String, dynamic> clientExtensionResults`
- `String? authenticatorAttachment`

**`PasskeyGetOptions`** (from Cognito's `CREDENTIAL_REQUEST_OPTIONS` challenge parameter):
- `String challenge` (base64url)
- `String rpId`
- `int? timeout`
- `List<PasskeyCredentialDescriptor>? allowCredentials`
- `String? userVerification`

**`PasskeyAssertionResponse`** (sub-type of get result):
- `String clientDataJSON` (base64url)
- `String authenticatorData` (base64url)
- `String signature` (base64url)
- `String? userHandle` (base64url, optional)

**`PasskeyGetResult`** (AuthenticationResponseJSON, sent as `CREDENTIAL` in RespondToAuthChallenge):
- `String id` (base64url credential ID)
- `String rawId` (base64url credential ID)
- `String type` (`'public-key'`)
- `PasskeyAssertionResponse response`
- `Map<String, dynamic> clientExtensionResults`
- `String? authenticatorAttachment`

### Task 3: Export from barrel file

**File:** `packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart`

Add export for the new types file so downstream packages can access them:
```dart
export 'src/model/webauthn/passkey_types.dart';
```

## Verification

1. All types compile without errors: `dart analyze packages/auth/amplify_auth_cognito_dart`
2. `PasskeyCreateOptions.fromJson(json)` correctly parses a sample Cognito `CredentialCreationOptions` JSON (see `.planning/research/cognito-webauthn-api.md` section 2 for format)
3. `PasskeyGetOptions.fromJson(json)` correctly parses a sample `CREDENTIAL_REQUEST_OPTIONS` JSON (see section 1)
4. `PasskeyCreateResult(...).toJson()` produces valid JSON matching the W3C `RegistrationResponseJSON` spec
5. `PasskeyGetResult(...).toJson()` produces valid JSON matching the W3C `AuthenticationResponseJSON` spec
6. `base64UrlEncode` / `base64UrlDecode` round-trip correctly for arbitrary byte sequences
7. All public members have dartdoc comments

## must_haves

- [ ] All 10 model classes are defined with `fromJson`/`toJson`
- [ ] Base64url encode/decode utilities handle padding normalization correctly
- [ ] Types match the W3C WebAuthn Level 3 JSON dictionary shapes as documented in `.planning/research/cognito-webauthn-api.md`
- [ ] Types are exported from the package barrel file
- [ ] All field names match Cognito's expected JSON keys exactly (camelCase: `clientDataJSON`, `attestationObject`, `authenticatorData`, `rawId`, `clientExtensionResults`, etc.)

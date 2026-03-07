---
wave: 2
depends_on: [02-PLAN.md]
files_modified:
  - packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart
  - packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart
requirements: [FLOW-05]
autonomous: true
---

# Plan 05: Raw HTTP Cognito WebAuthn API Clients

## Objective

Implement raw HTTP clients for the four Cognito WebAuthn API operations that are not in the Smithy-generated SDK: `StartWebAuthnRegistration`, `CompleteWebAuthnRegistration`, `ListWebAuthnCredentials`, and `DeleteWebAuthnCredential`. These are token-authorized (access token) operations that use the Cognito Identity Provider JSON 1.1 protocol.

## Context

The Smithy-generated SDK in `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/` does not include WebAuthn registration/management operations (see `.planning/research/cognito-webauthn-api.md` section 8). These must be implemented as raw HTTP calls against the Cognito Identity Provider service endpoint (`cognito-idp.{region}.amazonaws.com`).

The existing SDK uses the AWS JSON 1.1 protocol:
- `Content-Type: application/x-amz-json-1.1`
- `X-Amz-Target: AWSCognitoIdentityProviderService.{OperationName}`
- POST body is JSON
- Endpoint format: `https://cognito-idp.{region}.amazonaws.com/`

All four operations are access-token-authorized (not IAM-signed). The access token goes in the JSON body as `AccessToken`, not as an Authorization header.

## Tasks

### Task 1: Create CognitoWebAuthnClient class

**File:** `packages/auth/amplify_auth_cognito_dart/lib/src/sdk/cognito_webauthn_client.dart`

Create a new file with standard license header. The client should follow the patterns established by the existing `WrappedCognitoIdentityProviderClient` in `sdk_bridge.dart` but use raw HTTP since there are no Smithy-generated operations.

```dart
/// {@template amplify_auth_cognito_dart.sdk.cognito_webauthn_client}
/// Raw HTTP client for Cognito WebAuthn API operations not covered by
/// the Smithy-generated SDK.
/// {@endtemplate}
class CognitoWebAuthnClient {
  /// {@macro amplify_auth_cognito_dart.sdk.cognito_webauthn_client}
  const CognitoWebAuthnClient({
    required String region,
    required AWSHttpClient httpClient,
    String? endpoint,
  });
}
```

Constructor parameters:
- `region` -- AWS region (e.g., `us-east-1`)
- `httpClient` -- The `AmplifyHttpClient` from the dependency manager (`_dependencyManager.getOrCreate<AmplifyHttpClient>()`)
- `endpoint` -- Optional custom endpoint override (same pattern as `WrappedCognitoIdentityProviderClient`)

Internal helper method for making requests:
```dart
Future<Map<String, dynamic>> _makeRequest({
  required String target,  // e.g., 'AWSCognitoIdentityProviderService.StartWebAuthnRegistration'
  required Map<String, dynamic> body,
}) async {
  // Build URI from region or custom endpoint
  // Set headers: Content-Type, X-Amz-Target, Cache-Control
  // Send POST request via httpClient
  // Parse JSON response
  // Handle error responses (check for __type field)
}
```

Error handling: Parse error responses by checking for `__type` field in JSON response body. Map Cognito error types to the appropriate `CognitoServiceException` subtypes using the existing `transformSdkException` pattern, or throw new WebAuthn-specific exceptions. Key error types to handle:
- `WebAuthnNotEnabledException` -- passkeys not enabled on user pool
- `WebAuthnOriginNotAllowedException` -- origin mismatch
- `WebAuthnCredentialNotSupportedException` -- unsupported credential type
- `WebAuthnChallengeNotFoundException` -- challenge expired
- `WebAuthnClientMismatchException` -- client mismatch
- `LimitExceededException` -- max 20 passkeys
- `NotAuthorizedException` -- invalid/expired access token
- `ForbiddenException` -- WAF block

### Task 2: Implement StartWebAuthnRegistration

Method signature:
```dart
/// Starts WebAuthn credential registration by requesting creation options
/// from Cognito.
///
/// Requires a valid access token from an authenticated user session.
/// Returns [PasskeyCreateOptions] containing the credential creation
/// options to pass to the platform WebAuthn API.
Future<PasskeyCreateOptions> startWebAuthnRegistration({
  required String accessToken,
});
```

Request:
- Target: `AWSCognitoIdentityProviderService.StartWebAuthnRegistration`
- Body: `{"AccessToken": "<accessToken>"}`

Response parsing:
- Extract `CredentialCreationOptions` from response JSON
- Parse into `PasskeyCreateOptions` using `PasskeyCreateOptions.fromJson()`

### Task 3: Implement CompleteWebAuthnRegistration

Method signature:
```dart
/// Completes WebAuthn credential registration by sending the platform
/// ceremony result to Cognito.
///
/// [accessToken] must be the same session as [startWebAuthnRegistration].
/// [credential] is the [PasskeyCreateResult] from the platform ceremony.
Future<void> completeWebAuthnRegistration({
  required String accessToken,
  required PasskeyCreateResult credential,
});
```

Request:
- Target: `AWSCognitoIdentityProviderService.CompleteWebAuthnRegistration`
- Body: `{"AccessToken": "<accessToken>", "Credential": <credential.toJson()>}`

Response: HTTP 200 with empty body on success. No return value needed.

### Task 4: Implement ListWebAuthnCredentials

Method signature:
```dart
/// Lists WebAuthn credentials registered for the authenticated user.
///
/// Supports pagination via [maxResults] and [nextToken].
/// Returns a list of credential descriptions and an optional pagination token.
Future<ListWebAuthnCredentialsResult> listWebAuthnCredentials({
  required String accessToken,
  int? maxResults,
  String? nextToken,
});
```

Define a result type (can be in the same file or in `passkey_types.dart`):
```dart
/// Result of listing WebAuthn credentials.
class ListWebAuthnCredentialsResult {
  const ListWebAuthnCredentialsResult({
    required this.credentials,
    this.nextToken,
  });

  /// The list of WebAuthn credential descriptions.
  final List<WebAuthnCredentialDescription> credentials;

  /// Pagination token for fetching more results, or null if no more.
  final String? nextToken;
}

/// Description of a registered WebAuthn credential.
class WebAuthnCredentialDescription {
  const WebAuthnCredentialDescription({
    required this.credentialId,
    required this.relyingPartyId,
    required this.createdAt,
    this.friendlyCredentialName,
    this.authenticatorAttachment,
    this.authenticatorTransports,
  });

  factory WebAuthnCredentialDescription.fromJson(Map<String, dynamic> json);

  final String credentialId;
  final String relyingPartyId;
  final DateTime createdAt;
  final String? friendlyCredentialName;
  final String? authenticatorAttachment;
  final List<String>? authenticatorTransports;
}
```

Request:
- Target: `AWSCognitoIdentityProviderService.ListWebAuthnCredentials`
- Body: `{"AccessToken": "<accessToken>", "MaxResults": <maxResults>, "NextToken": "<nextToken>"}` (omit null fields)

Response parsing:
- Extract `Credentials` array and `NextToken` from response JSON
- Parse each credential using `WebAuthnCredentialDescription.fromJson()`
- `CreatedAt` is a Unix timestamp (seconds) -- convert to `DateTime`

### Task 5: Implement DeleteWebAuthnCredential

Method signature:
```dart
/// Deletes a WebAuthn credential from the user's account.
///
/// [credentialId] is the credential ID from [listWebAuthnCredentials].
Future<void> deleteWebAuthnCredential({
  required String accessToken,
  required String credentialId,
});
```

Request:
- Target: `AWSCognitoIdentityProviderService.DeleteWebAuthnCredential`
- Body: `{"AccessToken": "<accessToken>", "CredentialId": "<credentialId>"}`

Response: HTTP 200 with empty body on success.

### Task 6: Export from barrel file

**File:** `packages/auth/amplify_auth_cognito_dart/lib/amplify_auth_cognito_dart.dart`

Add export:
```dart
export 'src/sdk/cognito_webauthn_client.dart';
```

## Verification

1. `dart analyze packages/auth/amplify_auth_cognito_dart` -- no errors
2. `CognitoWebAuthnClient` can be instantiated with region, httpClient, and optional endpoint
3. All four methods have correct signatures and return types
4. `startWebAuthnRegistration` returns `PasskeyCreateOptions` (depends on types from Plan 02)
5. Error responses with `__type` field are mapped to appropriate exception types
6. `WebAuthnCredentialDescription.fromJson` correctly parses the Cognito response format
7. `ListWebAuthnCredentialsResult` includes pagination support
8. All public members have dartdoc comments

## must_haves

- [ ] `CognitoWebAuthnClient` class is implemented with all four Cognito WebAuthn operations
- [ ] `startWebAuthnRegistration` returns `PasskeyCreateOptions`
- [ ] `completeWebAuthnRegistration` accepts `PasskeyCreateResult` and access token
- [ ] `listWebAuthnCredentials` returns paginated `ListWebAuthnCredentialsResult` with `WebAuthnCredentialDescription` items
- [ ] `deleteWebAuthnCredential` accepts credential ID and access token
- [ ] Requests use correct `X-Amz-Target` headers and JSON body format
- [ ] Error responses are mapped to typed exceptions
- [ ] Client is exported from the package barrel file

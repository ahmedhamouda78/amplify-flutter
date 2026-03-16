// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// HRESULT success code.
const int S_OK = 0;

/// The user cancelled the operation.
const int NTE_USER_CANCELLED = 0x80090036;

/// The specified item was not found.
const int NTE_NOT_FOUND = 0x80090011;

/// An invalid parameter was passed to the function.
const int NTE_INVALID_PARAMETER = 0x80090027;

/// Minimum API version required for JSON pass-through support.
const int WEBAUTHN_API_VERSION_4 = 4;

/// Current API version for MakeCredential options struct (version 7).
const int WEBAUTHN_MAKE_CREDENTIAL_OPTIONS_VERSION = 7;

/// Current API version for GetAssertion options struct (version 7).
const int WEBAUTHN_GET_ASSERTION_OPTIONS_VERSION = 7;

/// Version for RP entity information struct.
const int WEBAUTHN_RP_ENTITY_INFORMATION_VERSION = 1;

/// Version for user entity information struct.
const int WEBAUTHN_USER_ENTITY_INFORMATION_VERSION = 1;

/// Version for client data struct.
const int WEBAUTHN_CLIENT_DATA_VERSION = 1;

/// Version for COSE credential parameter struct.
const int WEBAUTHN_COSE_CREDENTIAL_PARAMETER_VERSION = 1;

/// SHA-256 hash algorithm identifier.
const String WEBAUTHN_HASH_ALGORITHM_SHA_256 = 'SHA-256';

/// Public key credential type string.
const String WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY = 'public-key';

// --- Native function typedefs ---

/// `DWORD WebAuthNGetApiVersionNumber(void)`
typedef WebAuthNGetApiVersionNumberNative = Uint32 Function();
typedef WebAuthNGetApiVersionNumberDart = int Function();

/// `HRESULT WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable(
///   BOOL *pbIsUserVerifyingPlatformAuthenticatorAvailable
/// )`
typedef WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableNative
    = Int32 Function(Pointer<Int32> pbIsAvailable);
typedef WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableDart
    = int Function(Pointer<Int32> pbIsAvailable);

/// `HRESULT WebAuthNAuthenticatorMakeCredential(
///   HWND hWnd,
///   PCWEBAUTHN_RP_ENTITY_INFORMATION pRpInformation,
///   PCWEBAUTHN_USER_ENTITY_INFORMATION pUserInformation,
///   PCWEBAUTHN_COSE_CREDENTIAL_PARAMETERS pPubKeyCredParams,
///   PCWEBAUTHN_CLIENT_DATA pWebAuthNClientData,
///   PCWEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS pWebAuthNMakeCredentialOptions,
///   PWEBAUTHN_CREDENTIAL_ATTESTATION *ppWebAuthNCredentialAttestation
/// )`
typedef WebAuthNAuthenticatorMakeCredentialNative = Int32 Function(
  IntPtr hWnd,
  Pointer rpInfo,
  Pointer userInfo,
  Pointer pubKeyCredParams,
  Pointer clientData,
  Pointer options,
  Pointer<Pointer> ppResult,
);
typedef WebAuthNAuthenticatorMakeCredentialDart = int Function(
  int hWnd,
  Pointer rpInfo,
  Pointer userInfo,
  Pointer pubKeyCredParams,
  Pointer clientData,
  Pointer options,
  Pointer<Pointer> ppResult,
);

/// `HRESULT WebAuthNGetAssertion(
///   HWND hWnd,
///   LPCWSTR pwszRpId,
///   PCWEBAUTHN_CLIENT_DATA pWebAuthNClientData,
///   PCWEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS pWebAuthNGetAssertionOptions,
///   PWEBAUTHN_ASSERTION *ppWebAuthNAssertion
/// )`
typedef WebAuthNGetAssertionNative = Int32 Function(
  IntPtr hWnd,
  Pointer<Utf16> rpId,
  Pointer clientData,
  Pointer options,
  Pointer<Pointer> ppResult,
);
typedef WebAuthNGetAssertionDart = int Function(
  int hWnd,
  Pointer<Utf16> rpId,
  Pointer clientData,
  Pointer options,
  Pointer<Pointer> ppResult,
);

/// `void WebAuthNFreeCredentialAttestation(
///   PWEBAUTHN_CREDENTIAL_ATTESTATION pWebAuthNCredentialAttestation
/// )`
typedef WebAuthNFreeCredentialAttestationNative = Void Function(
  Pointer pAttestation,
);
typedef WebAuthNFreeCredentialAttestationDart = void Function(
  Pointer pAttestation,
);

/// `void WebAuthNFreeAssertion(PWEBAUTHN_ASSERTION pWebAuthNAssertion)`
typedef WebAuthNFreeAssertionNative = Void Function(Pointer pAssertion);
typedef WebAuthNFreeAssertionDart = void Function(Pointer pAssertion);

/// `HWND GetActiveWindow(void)` from user32.dll
typedef GetActiveWindowNative = IntPtr Function();
typedef GetActiveWindowDart = int Function();

/// {@template amplify_auth_cognito.webauthn_bindings}
/// FFI bindings to `webauthn.dll` and `user32.dll` for Windows WebAuthn
/// (Windows Hello FIDO2) API access.
///
/// Wraps function lookups in lazy final fields for testability. The
/// constructor accepts optional [DynamicLibrary] parameters to allow
/// injection in tests.
/// {@endtemplate}
class WebAuthnBindings {
  /// {@macro amplify_auth_cognito.webauthn_bindings}
  WebAuthnBindings({
    DynamicLibrary? webauthnLib,
    DynamicLibrary? user32Lib,
  })  : _webauthn = webauthnLib ?? DynamicLibrary.open('webauthn.dll'),
        _user32 = user32Lib ?? DynamicLibrary.open('user32.dll');

  final DynamicLibrary _webauthn;
  final DynamicLibrary _user32;

  /// Returns the API version number supported by the platform.
  late final WebAuthNGetApiVersionNumberDart getApiVersionNumber =
      _webauthn.lookupFunction<
          WebAuthNGetApiVersionNumberNative,
          WebAuthNGetApiVersionNumberDart>(
    'WebAuthNGetApiVersionNumber',
  );

  /// Checks whether a user-verifying platform authenticator is available.
  ///
  /// Writes a boolean value (as `Int32`) to the provided pointer.
  /// Returns an HRESULT indicating success or failure.
  late final WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableDart
      isUserVerifyingPlatformAuthenticatorAvailable =
      _webauthn.lookupFunction<
          WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableNative,
          WebAuthNIsUserVerifyingPlatformAuthenticatorAvailableDart>(
    'WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable',
  );

  /// Initiates a WebAuthn credential creation (registration) ceremony.
  ///
  /// Returns an HRESULT. On success, `ppResult` points to a
  /// `WEBAUTHN_CREDENTIAL_ATTESTATION` struct that must be freed with
  /// [freeCredentialAttestation].
  late final WebAuthNAuthenticatorMakeCredentialDart makeCredential =
      _webauthn.lookupFunction<
          WebAuthNAuthenticatorMakeCredentialNative,
          WebAuthNAuthenticatorMakeCredentialDart>(
    'WebAuthNAuthenticatorMakeCredential',
  );

  /// Initiates a WebAuthn assertion (authentication) ceremony.
  ///
  /// Returns an HRESULT. On success, `ppResult` points to a
  /// `WEBAUTHN_ASSERTION` struct that must be freed with [freeAssertion].
  late final WebAuthNGetAssertionDart getAssertion =
      _webauthn.lookupFunction<
          WebAuthNGetAssertionNative,
          WebAuthNGetAssertionDart>(
    'WebAuthNGetAssertion',
  );

  /// Frees a `WEBAUTHN_CREDENTIAL_ATTESTATION` struct returned by
  /// [makeCredential].
  late final WebAuthNFreeCredentialAttestationDart freeCredentialAttestation =
      _webauthn.lookupFunction<
          WebAuthNFreeCredentialAttestationNative,
          WebAuthNFreeCredentialAttestationDart>(
    'WebAuthNFreeCredentialAttestation',
  );

  /// Frees a `WEBAUTHN_ASSERTION` struct returned by [getAssertion].
  late final WebAuthNFreeAssertionDart freeAssertion =
      _webauthn.lookupFunction<
          WebAuthNFreeAssertionNative,
          WebAuthNFreeAssertionDart>(
    'WebAuthNFreeAssertion',
  );

  /// Returns the handle to the active window (from `user32.dll`).
  ///
  /// Used to obtain the `HWND` parameter required by
  /// [makeCredential] and [getAssertion].
  late final GetActiveWindowDart getActiveWindow =
      _user32.lookupFunction<GetActiveWindowNative, GetActiveWindowDart>(
    'GetActiveWindow',
  );
}

// ---------------------------------------------------------------------------
// Struct layout helpers
//
// The Windows WebAuthn structs are large and version-dependent. Rather than
// defining full `Struct` subclasses (which would require correctly aligning
// 20+ fields including nested pointers across versions), we allocate raw
// memory and write fields at known byte offsets for the JSON pass-through
// fields we need.
//
// All sizes assume 64-bit Windows (LLP64: int=4, pointer=8, DWORD=4).
// ---------------------------------------------------------------------------

/// Byte offsets within `WEBAUTHN_RP_ENTITY_INFORMATION` (version 1).
///
/// Layout:
/// ```
/// DWORD dwVersion;          // offset 0, size 4
/// // 4 bytes padding
/// PCWSTR pwszId;             // offset 8, size 8
/// PCWSTR pwszName;           // offset 16, size 8
/// PCWSTR pwszIcon;           // offset 24, size 8
/// ```
abstract final class RpEntityOffsets {
  static const int dwVersion = 0;
  static const int pwszId = 8;
  static const int pwszName = 16;
  static const int pwszIcon = 24;
  static const int structSize = 32;
}

/// Byte offsets within `WEBAUTHN_USER_ENTITY_INFORMATION` (version 1).
///
/// Layout:
/// ```
/// DWORD dwVersion;          // offset 0, size 4
/// DWORD cbId;               // offset 4, size 4
/// PBYTE pbId;               // offset 8, size 8
/// PCWSTR pwszName;           // offset 16, size 8
/// PCWSTR pwszIcon;           // offset 24, size 8
/// PCWSTR pwszDisplayName;    // offset 32, size 8
/// ```
abstract final class UserEntityOffsets {
  static const int dwVersion = 0;
  static const int cbId = 4;
  static const int pbId = 8;
  static const int pwszName = 16;
  static const int pwszIcon = 24;
  static const int pwszDisplayName = 32;
  static const int structSize = 40;
}

/// Byte offsets within `WEBAUTHN_COSE_CREDENTIAL_PARAMETER` (version 1).
///
/// Layout:
/// ```
/// DWORD dwVersion;           // offset 0, size 4
/// // 4 bytes padding
/// PCWSTR pwszCredentialType;  // offset 8, size 8
/// LONG lAlg;                 // offset 16, size 4
/// // 4 bytes padding (to align struct to 8)
/// ```
abstract final class CoseCredentialParameterOffsets {
  static const int dwVersion = 0;
  static const int pwszCredentialType = 8;
  static const int lAlg = 16;
  static const int structSize = 24;
}

/// Byte offsets within `WEBAUTHN_COSE_CREDENTIAL_PARAMETERS`.
///
/// Layout:
/// ```
/// DWORD cCredentialParameters;                        // offset 0, size 4
/// // 4 bytes padding
/// PWEBAUTHN_COSE_CREDENTIAL_PARAMETER pCredParams;   // offset 8, size 8
/// ```
abstract final class CoseCredentialParametersOffsets {
  static const int cCredentialParameters = 0;
  static const int pCredentialParameters = 8;
  static const int structSize = 16;
}

/// Byte offsets within `WEBAUTHN_CLIENT_DATA` (version 1).
///
/// Layout:
/// ```
/// DWORD dwVersion;           // offset 0, size 4
/// DWORD cbClientDataJSON;    // offset 4, size 4
/// PBYTE pbClientDataJSON;    // offset 8, size 8
/// PCWSTR pwszHashAlgId;      // offset 16, size 8
/// ```
abstract final class ClientDataOffsets {
  static const int dwVersion = 0;
  static const int cbClientDataJSON = 4;
  static const int pbClientDataJSON = 8;
  static const int pwszHashAlgId = 16;
  static const int structSize = 24;
}

/// Size and key offsets for `WEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS`
/// version 7 struct.
///
/// This is a large struct (~200+ bytes). We only define offsets for fields
/// we actively set: the version, timeout, and the JSON pass-through fields
/// added in version 5.
///
/// The JSON pass-through fields are at the END of the struct (after all
/// v1-v4 fields). Exact offsets are calculated from the Windows SDK
/// `webauthn.h` header for the 64-bit ABI.
abstract final class MakeCredentialOptionsOffsets {
  /// `DWORD dwVersion` at offset 0.
  static const int dwVersion = 0;

  /// `DWORD dwTimeoutMilliseconds` at offset 4.
  static const int dwTimeoutMilliseconds = 4;

  // Version 5 JSON pass-through fields (appended after v4 fields):

  /// `DWORD cbPublicKeyCredentialCreationOptionsJSON` — byte length of JSON.
  static const int cbJsonOptions = 192;

  /// `PBYTE pbPublicKeyCredentialCreationOptionsJSON` — pointer to JSON bytes.
  static const int pbJsonOptions = 200;

  /// Total struct size for version 7 (rounded up to pointer alignment).
  static const int structSize = 208;
}

/// Size and key offsets for `WEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS`
/// version 7 struct.
///
/// Similar to [MakeCredentialOptionsOffsets], we only populate the version,
/// timeout, and JSON pass-through fields (added in version 6).
abstract final class GetAssertionOptionsOffsets {
  /// `DWORD dwVersion` at offset 0.
  static const int dwVersion = 0;

  /// `DWORD dwTimeoutMilliseconds` at offset 4.
  static const int dwTimeoutMilliseconds = 4;

  // Version 6 JSON pass-through fields:

  /// `DWORD cbPublicKeyCredentialRequestOptionsJSON` — byte length of JSON.
  static const int cbJsonOptions = 160;

  /// `PBYTE pbPublicKeyCredentialRequestOptionsJSON` — pointer to JSON bytes.
  static const int pbJsonOptions = 168;

  /// Total struct size for version 7 (rounded up to pointer alignment).
  static const int structSize = 176;
}

/// Key offsets within `WEBAUTHN_CREDENTIAL_ATTESTATION` for reading the
/// JSON registration response.
///
/// The struct has many fields; we only need the JSON response fields
/// added in version 4:
/// - `cbRegistrationResponseJSON` (DWORD)
/// - `pbRegistrationResponseJSON` (PBYTE)
///
/// These are at the end of the v3 struct + extensions.
abstract final class CredentialAttestationOffsets {
  /// `DWORD cbRegistrationResponseJSON` — byte length of JSON response.
  static const int cbRegistrationResponseJSON = 152;

  /// `PBYTE pbRegistrationResponseJSON` — pointer to JSON response bytes.
  static const int pbRegistrationResponseJSON = 160;
}

/// Key offsets within `WEBAUTHN_ASSERTION` for reading the JSON
/// authentication response.
///
/// - `cbAuthenticationResponseJSON` (DWORD)
/// - `pbAuthenticationResponseJSON` (PBYTE)
///
/// Added in version 3 of the assertion struct.
abstract final class AssertionOffsets {
  /// `DWORD cbAuthenticationResponseJSON` — byte length of JSON response.
  static const int cbAuthenticationResponseJSON = 104;

  /// `PBYTE pbAuthenticationResponseJSON` — pointer to JSON response bytes.
  static const int pbAuthenticationResponseJSON = 112;
}

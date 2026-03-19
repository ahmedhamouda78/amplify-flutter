// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:amplify_auth_cognito/src/windows/webauthn_bindings.dart';
// ignore: implementation_imports
import 'package:amplify_auth_cognito_dart/src/model/webauthn/webauthn_credential_platform.dart';
import 'package:amplify_core/amplify_core.dart';
import 'package:ffi/ffi.dart';

/// {@template amplify_auth_cognito.windows_webauthn_platform}
/// Windows implementation of [WebAuthnCredentialPlatform] using the
/// Windows Hello FIDO2 API (`webauthn.dll`) via FFI.
///
/// Uses the JSON pass-through mode available in Windows WebAuthn API
/// version 4+ to avoid manually constructing the full C struct hierarchy.
/// The JSON options from Cognito are passed directly to the native API,
/// and the JSON response is read directly from the result struct.
/// {@endtemplate}
class WindowsWebAuthnPlatform implements WebAuthnCredentialPlatform {
  /// {@macro amplify_auth_cognito.windows_webauthn_platform}
  ///
  /// Accepts an optional [WebAuthnBindings] for testability.
  WindowsWebAuthnPlatform({WebAuthnBindings? bindings})
    : _bindings = bindings ?? WebAuthnBindings();

  final WebAuthnBindings _bindings;

  /// Cached API version number.
  late final int _apiVersion = _bindings.getApiVersionNumber();

  @override
  Future<bool> isPasskeySupported() async {
    try {
      // Check if the API version supports JSON pass-through.
      if (_apiVersion < WEBAUTHN_API_VERSION_4) {
        return false;
      }

      final pbIsAvailable = calloc<Int32>();
      try {
        final hr = _bindings.isUserVerifyingPlatformAuthenticatorAvailable(
          pbIsAvailable,
        );
        if (hr != S_OK) {
          return false;
        }
        return pbIsAvailable.value != 0;
      } finally {
        calloc.free(pbIsAvailable);
      }
    } on Exception {
      // If the DLL cannot be loaded or any other error occurs,
      // passkeys are not supported.
      return false;
    }
  }

  @override
  Future<String> createCredential(String optionsJson) async {
    final hWnd = _bindings.getActiveWindow();
    if (hWnd == 0) {
      throw const PasskeyRegistrationFailedException(
        'No active window available for WebAuthn ceremony',
        recoverySuggestion:
            'Ensure the application window is in the foreground.',
      );
    }

    if (_apiVersion < WEBAUTHN_API_VERSION_4) {
      throw const PasskeyNotSupportedException(
        'Windows WebAuthn API version 4+ is required for passkey support',
      );
    }

    final optionsMap = json.decode(optionsJson) as Map<String, dynamic>;

    // Extract required fields for the C structs.
    final rp = optionsMap['rp'] as Map<String, dynamic>;
    final rpId = rp['id'] as String? ?? '';
    final rpName = rp['name'] as String? ?? '';
    final user = optionsMap['user'] as Map<String, dynamic>;
    final userName = user['name'] as String? ?? '';
    final userDisplayName = user['displayName'] as String? ?? '';
    final userId = user['id'] as String? ?? '';
    final userIdBytes = utf8.encode(userId);
    final pubKeyCredParams =
        (optionsMap['pubKeyCredParams'] as List<dynamic>?) ?? [];

    // Encode the full options JSON as UTF-8 for pass-through.
    final optionsJsonBytes = utf8.encode(optionsJson);

    // Allocate a dummy client data (required parameter, but JSON
    // pass-through mode uses the options JSON directly).
    final dummyClientData = utf8.encode('{}');

    final arena = Arena();
    Pointer pAttestation = nullptr;
    try {
      // --- RP Entity ---
      final rpInfo = arena<Uint8>(RpEntityOffsets.structSize);
      _zeroMemory(rpInfo, RpEntityOffsets.structSize);
      rpInfo.cast<Uint32>().value = WEBAUTHN_RP_ENTITY_INFORMATION_VERSION;
      _writePointerAt(
        rpInfo,
        RpEntityOffsets.pwszId,
        rpId.toNativeUtf16(allocator: arena).cast(),
      );
      _writePointerAt(
        rpInfo,
        RpEntityOffsets.pwszName,
        rpName.toNativeUtf16(allocator: arena).cast(),
      );

      // --- User Entity ---
      final userInfo = arena<Uint8>(UserEntityOffsets.structSize);
      _zeroMemory(userInfo, UserEntityOffsets.structSize);
      userInfo.cast<Uint32>().value = WEBAUTHN_USER_ENTITY_INFORMATION_VERSION;
      _writeUint32At(userInfo, UserEntityOffsets.cbId, userIdBytes.length);
      final pbUserId = arena<Uint8>(userIdBytes.length);
      pbUserId.asTypedList(userIdBytes.length).setAll(0, userIdBytes);
      _writePointerAt(userInfo, UserEntityOffsets.pbId, pbUserId);
      _writePointerAt(
        userInfo,
        UserEntityOffsets.pwszName,
        userName.toNativeUtf16(allocator: arena).cast(),
      );
      _writePointerAt(
        userInfo,
        UserEntityOffsets.pwszDisplayName,
        userDisplayName.toNativeUtf16(allocator: arena).cast(),
      );

      // --- COSE Credential Parameters ---
      final paramCount = pubKeyCredParams.length;
      final credParamsArray = paramCount > 0
          ? arena<Uint8>(CoseCredentialParameterOffsets.structSize * paramCount)
          : nullptr.cast<Uint8>();
      final credTypeStr = WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY.toNativeUtf16(
        allocator: arena,
      );
      for (var i = 0; i < paramCount; i++) {
        final param = pubKeyCredParams[i] as Map<String, dynamic>;
        final alg = param['alg'] as int? ?? -7; // ES256 default
        final offset = i * CoseCredentialParameterOffsets.structSize;
        final entry = credParamsArray + offset;
        _zeroMemory(entry, CoseCredentialParameterOffsets.structSize);
        entry.cast<Uint32>().value = WEBAUTHN_COSE_CREDENTIAL_PARAMETER_VERSION;
        _writePointerAt(
          entry,
          CoseCredentialParameterOffsets.pwszCredentialType,
          credTypeStr.cast(),
        );
        _writeInt32At(entry, CoseCredentialParameterOffsets.lAlg, alg);
      }

      final credParams = arena<Uint8>(
        CoseCredentialParametersOffsets.structSize,
      );
      _zeroMemory(credParams, CoseCredentialParametersOffsets.structSize);
      credParams.cast<Uint32>().value = paramCount;
      _writePointerAt(
        credParams,
        CoseCredentialParametersOffsets.pCredentialParameters,
        credParamsArray,
      );

      // --- Client Data ---
      final clientData = arena<Uint8>(ClientDataOffsets.structSize);
      _zeroMemory(clientData, ClientDataOffsets.structSize);
      clientData.cast<Uint32>().value = WEBAUTHN_CLIENT_DATA_VERSION;
      _writeUint32At(
        clientData,
        ClientDataOffsets.cbClientDataJSON,
        dummyClientData.length,
      );
      final pbClientData = arena<Uint8>(dummyClientData.length);
      pbClientData
          .asTypedList(dummyClientData.length)
          .setAll(0, dummyClientData);
      _writePointerAt(
        clientData,
        ClientDataOffsets.pbClientDataJSON,
        pbClientData,
      );
      _writePointerAt(
        clientData,
        ClientDataOffsets.pwszHashAlgId,
        WEBAUTHN_HASH_ALGORITHM_SHA_256.toNativeUtf16(allocator: arena).cast(),
      );

      // --- MakeCredential Options (with JSON pass-through) ---
      final options = arena<Uint8>(MakeCredentialOptionsOffsets.structSize);
      _zeroMemory(options, MakeCredentialOptionsOffsets.structSize);
      options.cast<Uint32>().value = WEBAUTHN_MAKE_CREDENTIAL_OPTIONS_VERSION;
      _writeUint32At(
        options,
        MakeCredentialOptionsOffsets.dwTimeoutMilliseconds,
        120000,
      );

      // JSON pass-through fields
      _writeUint32At(
        options,
        MakeCredentialOptionsOffsets.cbJsonOptions,
        optionsJsonBytes.length,
      );
      final pbJsonOptions = arena<Uint8>(optionsJsonBytes.length);
      pbJsonOptions
          .asTypedList(optionsJsonBytes.length)
          .setAll(0, optionsJsonBytes);
      _writePointerAt(
        options,
        MakeCredentialOptionsOffsets.pbJsonOptions,
        pbJsonOptions,
      );

      // --- Call MakeCredential ---
      final ppResult = arena<Pointer>();
      final hr = _bindings.makeCredential(
        hWnd,
        rpInfo.cast(),
        userInfo.cast(),
        credParams.cast(),
        clientData.cast(),
        options.cast(),
        ppResult,
      );

      if (hr != S_OK) {
        _throwHResultError(hr, isRegistration: true);
      }

      pAttestation = ppResult.value;

      // Read JSON response from the attestation result struct.
      final cbJson =
          (pAttestation.cast<Uint8>() +
                  CredentialAttestationOffsets.cbRegistrationResponseJSON)
              .cast<Uint32>()
              .value;
      final pbJson = _readPointerAt(
        pAttestation.cast<Uint8>(),
        CredentialAttestationOffsets.pbRegistrationResponseJSON,
      );

      if (cbJson == 0 || pbJson == nullptr) {
        throw const PasskeyRegistrationFailedException(
          'Windows WebAuthn returned empty registration response',
        );
      }

      final jsonString = utf8.decode(
        Uint8List.fromList(pbJson.cast<Uint8>().asTypedList(cbJson)),
      );

      // Ensure clientExtensionResults is present (required by PasskeyCreateResult.fromJson)
      return _ensureClientExtensionResults(jsonString);
    } finally {
      // Free attestation struct if it was allocated by the API.
      if (pAttestation != nullptr) {
        _bindings.freeCredentialAttestation(pAttestation);
      }
      arena.releaseAll();
    }
  }

  @override
  Future<String> getCredential(String optionsJson) async {
    final hWnd = _bindings.getActiveWindow();
    if (hWnd == 0) {
      throw const PasskeyAssertionFailedException(
        'No active window available for WebAuthn ceremony',
        recoverySuggestion:
            'Ensure the application window is in the foreground.',
      );
    }

    if (_apiVersion < WEBAUTHN_API_VERSION_4) {
      throw const PasskeyNotSupportedException(
        'Windows WebAuthn API version 4+ is required for passkey support',
      );
    }

    final optionsMap = json.decode(optionsJson) as Map<String, dynamic>;
    final rpId = optionsMap['rpId'] as String? ?? '';

    // Encode the full options JSON as UTF-8 for pass-through.
    final optionsJsonBytes = utf8.encode(optionsJson);

    // Dummy client data (required parameter).
    final dummyClientData = utf8.encode('{}');

    final arena = Arena();
    Pointer pAssertion = nullptr;
    try {
      // --- Client Data ---
      final clientData = arena<Uint8>(ClientDataOffsets.structSize);
      _zeroMemory(clientData, ClientDataOffsets.structSize);
      clientData.cast<Uint32>().value = WEBAUTHN_CLIENT_DATA_VERSION;
      _writeUint32At(
        clientData,
        ClientDataOffsets.cbClientDataJSON,
        dummyClientData.length,
      );
      final pbClientData = arena<Uint8>(dummyClientData.length);
      pbClientData
          .asTypedList(dummyClientData.length)
          .setAll(0, dummyClientData);
      _writePointerAt(
        clientData,
        ClientDataOffsets.pbClientDataJSON,
        pbClientData,
      );
      _writePointerAt(
        clientData,
        ClientDataOffsets.pwszHashAlgId,
        WEBAUTHN_HASH_ALGORITHM_SHA_256.toNativeUtf16(allocator: arena).cast(),
      );

      // --- GetAssertion Options (with JSON pass-through) ---
      final options = arena<Uint8>(GetAssertionOptionsOffsets.structSize);
      _zeroMemory(options, GetAssertionOptionsOffsets.structSize);
      options.cast<Uint32>().value = WEBAUTHN_GET_ASSERTION_OPTIONS_VERSION;
      _writeUint32At(
        options,
        GetAssertionOptionsOffsets.dwTimeoutMilliseconds,
        120000,
      );

      // JSON pass-through fields
      _writeUint32At(
        options,
        GetAssertionOptionsOffsets.cbJsonOptions,
        optionsJsonBytes.length,
      );
      final pbJsonOptions = arena<Uint8>(optionsJsonBytes.length);
      pbJsonOptions
          .asTypedList(optionsJsonBytes.length)
          .setAll(0, optionsJsonBytes);
      _writePointerAt(
        options,
        GetAssertionOptionsOffsets.pbJsonOptions,
        pbJsonOptions,
      );

      // --- Call GetAssertion ---
      final ppResult = arena<Pointer>();
      final rpIdNative = rpId.toNativeUtf16(allocator: arena);
      final hr = _bindings.getAssertion(
        hWnd,
        rpIdNative,
        clientData.cast(),
        options.cast(),
        ppResult,
      );

      if (hr != S_OK) {
        _throwHResultError(hr, isRegistration: false);
      }

      pAssertion = ppResult.value;

      // Read JSON response from the assertion result struct.
      final cbJson =
          (pAssertion.cast<Uint8>() +
                  AssertionOffsets.cbAuthenticationResponseJSON)
              .cast<Uint32>()
              .value;
      final pbJson = _readPointerAt(
        pAssertion.cast<Uint8>(),
        AssertionOffsets.pbAuthenticationResponseJSON,
      );

      if (cbJson == 0 || pbJson == nullptr) {
        throw const PasskeyAssertionFailedException(
          'Windows WebAuthn returned empty authentication response',
        );
      }

      final jsonString = utf8.decode(
        Uint8List.fromList(pbJson.cast<Uint8>().asTypedList(cbJson)),
      );

      // Ensure clientExtensionResults is present (required by PasskeyGetResult.fromJson)
      return _ensureClientExtensionResults(jsonString);
    } finally {
      // Free assertion struct if it was allocated by the API.
      if (pAssertion != nullptr) {
        _bindings.freeAssertion(pAssertion);
      }
      arena.releaseAll();
    }
  }

  /// Maps a Windows HRESULT error code to the appropriate
  /// [PasskeyException] subtype.
  Never _throwHResultError(int hr, {required bool isRegistration}) {
    final hexCode = '0x${hr.toRadixString(16).padLeft(8, '0')}';
    final message = 'Windows WebAuthn error: $hexCode';

    switch (hr) {
      case NTE_USER_CANCELLED:
        throw PasskeyCancelledException(message);
      case NTE_NOT_FOUND:
        throw PasskeyAssertionFailedException(message);
      case NTE_INVALID_PARAMETER:
        if (isRegistration) {
          throw PasskeyRegistrationFailedException(message);
        }
        throw PasskeyAssertionFailedException(message);
      default:
        if (isRegistration) {
          throw PasskeyRegistrationFailedException(message);
        }
        throw PasskeyAssertionFailedException(message);
    }
  }

  // ---------------------------------------------------------------------------
  // Memory helpers
  // ---------------------------------------------------------------------------

  /// Writes a 32-bit unsigned integer at [offset] bytes from [base].
  static void _writeUint32At(Pointer<Uint8> base, int offset, int value) {
    (base + offset).cast<Uint32>().value = value;
  }

  /// Writes a 32-bit signed integer at [offset] bytes from [base].
  static void _writeInt32At(Pointer<Uint8> base, int offset, int value) {
    (base + offset).cast<Int32>().value = value;
  }

  /// Writes a pointer value at [offset] bytes from [base].
  static void _writePointerAt(Pointer<Uint8> base, int offset, Pointer value) {
    (base + offset).cast<Pointer>().value = value;
  }

  /// Reads a pointer value at [offset] bytes from [base].
  static Pointer _readPointerAt(Pointer<Uint8> base, int offset) {
    return (base + offset).cast<Pointer>().value;
  }

  /// Zeroes [size] bytes of memory starting at [base].
  static void _zeroMemory(Pointer<Uint8> base, int size) {
    for (var i = 0; i < size; i++) {
      (base + i).value = 0;
    }
  }

  /// Ensures that the JSON response contains a `clientExtensionResults` field.
  ///
  /// The Windows WebAuthn API v4+ may not include this field, but
  /// PasskeyCreateResult.fromJson and PasskeyGetResult.fromJson require it
  /// (non-nullable field). This function parses the JSON, adds the field if
  /// missing, and returns the updated JSON string.
  static String _ensureClientExtensionResults(String jsonString) {
    try {
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      if (!jsonMap.containsKey('clientExtensionResults')) {
        jsonMap['clientExtensionResults'] = <String, dynamic>{};
      }
      return json.encode(jsonMap);
    } on Object {
      // If parsing fails, return original JSON (let caller handle the error)
      return jsonString;
    }
  }
}

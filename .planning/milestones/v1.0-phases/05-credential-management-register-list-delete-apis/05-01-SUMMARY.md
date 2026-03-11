---
phase: 05-credential-management-register-list-delete-apis
plan: 01
subsystem: amplify_core public API
tags: [api-surface, types, contracts, webauthn]
dependency_graph:
  requires: []
  provides:
    - AuthWebAuthnCredential type
    - 4 WebAuthn method contracts
  affects:
    - packages/amplify_core/lib/src/types/auth
    - packages/amplify_core/lib/src/plugin
    - packages/amplify_core/lib/src/category
tech_stack:
  added: []
  patterns:
    - Abstract base class with AWSSerializable mixin
    - Plugin interface stubs with UnimplementedError
    - Category delegation via identifyCall
    - Enum-based method tracking
key_files:
  created:
    - packages/amplify_core/lib/src/types/auth/credential/auth_webauthn_credential.dart
  modified:
    - packages/amplify_core/lib/src/types/auth/auth_types.dart
    - packages/amplify_core/lib/src/plugin/amplify_auth_plugin_interface.dart
    - packages/amplify_core/lib/src/category/amplify_auth_category.dart
    - packages/amplify_core/lib/src/http/amplify_category_method.dart
decisions: []
metrics:
  duration_minutes: 3
  tasks_completed: 2
  files_created: 1
  files_modified: 4
  commits: 2
  completed_at: "2026-03-10T15:27:45Z"
---

# Phase 05 Plan 01: Core API Surface for Credential Management Summary

**One-liner:** Established public API contracts for passkey credential management via AuthWebAuthnCredential type, 4 method stubs on AuthPluginInterface, forwarding methods on AuthCategory, and AuthCategoryMethod enum entries.

## Objective

Define the public API surface for passkey credential management in amplify_core: the AuthWebAuthnCredential model type, 4 method stubs on AuthPluginInterface, 4 forwarding methods on AuthCategory, and AuthCategoryMethod enum entries.

## What Was Built

### Task 1: AuthWebAuthnCredential Model
**Status:** ✅ Complete
**Commit:** 9a7b222f8

Created the abstract `AuthWebAuthnCredential` class following the `AuthDevice` pattern:
- Annotated with `@immutable`
- Mixes in `AWSSerializable<Map<String, Object?>>`
- 6 fields: `credentialId`, `friendlyName`, `relyingPartyId`, `authenticatorAttachment`, `authenticatorTransports`, `createdAt`
- Required getters: `credentialId`, `relyingPartyId`, `createdAt`
- Optional getters: `friendlyName`, `authenticatorAttachment`, `authenticatorTransports`
- Abstract `toJson()` method
- `toString()` implementation showing key fields
- Dartdoc with category tag and template
- Exported from `auth_types.dart` barrel under "Credentials" section

### Task 2: Method Stubs and Forwarding
**Status:** ✅ Complete
**Commit:** 85a935a3e

Added 4 WebAuthn operations to the plugin interface and category:

**AuthPluginInterface stubs:**
- `associateWebAuthnCredential()` - Returns `Future<void>`
- `listWebAuthnCredentials()` - Returns `Future<List<AuthWebAuthnCredential>>`
- `deleteWebAuthnCredential(String credentialId)` - Returns `Future<void>`
- `isPasskeySupported()` - Returns `Future<bool>`

All stubs throw `UnimplementedError` with descriptive messages and use dartdoc references to AuthCategory templates.

**AuthCategory forwarding methods:**
- All 4 methods delegate to `defaultPlugin` via `identifyCall` pattern
- Dartdoc templates define the canonical method documentation
- Clear descriptions of authentication requirements and behavior

**AuthCategoryMethod enum entries:**
- Added entries 60-63: `associateWebAuthnCredential`, `listWebAuthnCredentials`, `deleteWebAuthnCredential`, `isPasskeySupported`
- Sequential IDs following existing pattern (59 was `fetchCurrentDevice`)

## Deviations from Plan

None - plan executed exactly as written.

## Success Criteria

- [x] AuthWebAuthnCredential abstract class defined with credentialId, friendlyName, relyingPartyId, authenticatorAttachment, authenticatorTransports, createdAt
- [x] AuthPluginInterface has associateWebAuthnCredential(), listWebAuthnCredentials(), deleteWebAuthnCredential(String), isPasskeySupported()
- [x] AuthCategory forwards all 4 to defaultPlugin via identifyCall
- [x] AuthCategoryMethod enum has 4 new entries
- [x] dart analyze packages/amplify_core passes clean (no errors, only pre-existing style info)

## Technical Details

### API Signatures

```dart
// Model
abstract class AuthWebAuthnCredential with AWSSerializable<Map<String, Object?>> {
  String get credentialId;
  String? get friendlyName;
  String get relyingPartyId;
  String? get authenticatorAttachment;
  List<String>? get authenticatorTransports;
  DateTime get createdAt;
  Map<String, Object?> toJson();
}

// Methods
Future<void> associateWebAuthnCredential()
Future<List<AuthWebAuthnCredential>> listWebAuthnCredentials()
Future<void> deleteWebAuthnCredential(String credentialId)
Future<bool> isPasskeySupported()
```

### Design Decisions

1. **No options parameter on `associateWebAuthnCredential()`** - User decision from context. Ceremony is fully orchestrated internally.
2. **`credentialId` as required String parameter on `deleteWebAuthnCredential()`** - User decision from context. Follows direct identifier pattern.
3. **Return type `List<AuthWebAuthnCredential>`** - Follows `fetchDevices()` pattern for consistency.
4. **Enum IDs 60-63** - Sequential continuation from existing entries.

## Files Modified

**Created:**
- `packages/amplify_core/lib/src/types/auth/credential/auth_webauthn_credential.dart` (45 lines)

**Modified:**
- `packages/amplify_core/lib/src/types/auth/auth_types.dart` (+2 lines export)
- `packages/amplify_core/lib/src/plugin/amplify_auth_plugin_interface.dart` (+26 lines)
- `packages/amplify_core/lib/src/category/amplify_auth_category.dart` (+52 lines)
- `packages/amplify_core/lib/src/http/amplify_category_method.dart` (+4 lines)

## Verification

```bash
cd /Users/rhamouda/Work/AmplifyDev/Fork/amplify-flutter/packages/amplify_core
dart analyze --no-fatal-warnings
# Result: 192 info issues (pre-existing style suggestions), 0 errors
```

All analysis issues are info-level linting suggestions in doc examples, not in production code.

## Next Steps

Plan 02 will implement these contracts in the Cognito plugin:
- `CognitoWebAuthnCredential` concrete implementation
- HTTP operations using raw AWS JSON 1.1 protocol
- Integration with state machine and platform bridge

## Self-Check: PASSED

All files and commits verified:

- ✅ FOUND: auth_webauthn_credential.dart
- ✅ FOUND: export in auth_types.dart
- ✅ FOUND: plugin stubs in amplify_auth_plugin_interface.dart
- ✅ FOUND: category methods in amplify_auth_category.dart
- ✅ FOUND: enum entries in amplify_category_method.dart
- ✅ FOUND: commit 9a7b222f8 (Task 1)
- ✅ FOUND: commit 85a935a3e (Task 2)

---
phase: 03-platform-bridges-ios-android-web
plan: 02
subsystem: auth
tags: [webauthn, passkey, ios, macos, darwin, swift, ASAuthorizationController, platform-bridge]

# Dependency graph
requires:
  - phase: 01-core-types-and-models
    provides: "PasskeyException hierarchy and WebAuthnCredentialPlatform interface"
  - phase: 03-platform-bridges-ios-android-web
    plan: 01
    provides: "Pigeon-generated WebAuthnBridgeApi protocol and WebAuthnBridgeApiSetup in Swift"
provides:
  - "iOS/macOS WebAuthn bridge implementing all 3 Pigeon WebAuthnBridgeApi methods"
  - "ASAuthorizationController-based passkey registration and assertion ceremonies"
  - "Plugin registration wiring for WebAuthn bridge in AmplifyAuthCognitoPlugin"
affects: []

# Tech tracking
tech-stack:
  added: [AuthenticationServices]
  patterns: [ASAuthorizationController-delegate-with-ARC-safe-storage, base64url-data-extension, PigeonError-error-mapping]

key-files:
  created:
    - packages/auth/amplify_auth_cognito/darwin/Classes/WebAuthnBridgeImpl.swift
  modified:
    - packages/auth/amplify_auth_cognito/darwin/Classes/AmplifyAuthCognitoPlugin.swift

key-decisions:
  - "Used PigeonError (not FlutterError) for error propagation -- matches Pigeon-generated wrapError handling"
  - "Stored activeController and pendingCompletion as instance properties to prevent ARC deallocation during ceremony"
  - "isRegistration flag tracks ceremony type for context-appropriate error code defaults"

patterns-established:
  - "Darwin WebAuthn pattern: parse JSON -> create ASAuthorizationPlatformPublicKeyCredentialProvider -> delegate callbacks -> serialize response JSON"
  - "Base64url Data extension for WebAuthn binary field encoding/decoding"

requirements-completed: [PLAT-01, PLAT-08]

# Metrics
duration: 2min
completed: 2026-03-09
---

# Phase 3 Plan 02: iOS/Darwin WebAuthn Bridge Summary

**ASAuthorizationController-based passkey bridge for iOS 17.4+/macOS 13.5+ with registration, assertion, and capability detection**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-09T15:11:01Z
- **Completed:** 2026-03-09T15:13:22Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created WebAuthnBridgeImpl.swift (388 lines) implementing all 3 WebAuthnBridgeApi protocol methods using ASAuthorizationController
- Implemented createCredential with JSON parsing, ASAuthorizationPlatformPublicKeyCredentialProvider registration, excludeCredentials support, and base64url response serialization
- Implemented getCredential with assertion request, allowedCredentials support, and userHandle handling
- isPasskeySupported uses runtime #available(iOS 17.4, macOS 13.5, *) check
- Complete ASAuthorizationError.Code mapping to all 5 standardized error codes (cancelled, notSupported, registrationFailed, assertionFailed, matchedExcludedCredential)
- Registered WebAuthn bridge in AmplifyAuthCognitoPlugin.register(with:) alongside existing NativeAuthBridge

## Task Commits

Each task was committed atomically:

1. **Task 1: Create WebAuthnBridgeImpl.swift with ASAuthorizationController-based passkey ceremonies** - `28e7c97b5` (feat)
2. **Task 2: Register WebAuthn bridge in AmplifyAuthCognitoPlugin.swift** - `898ad18de` (feat)

## Files Created/Modified
- `packages/auth/amplify_auth_cognito/darwin/Classes/WebAuthnBridgeImpl.swift` - Full iOS/macOS WebAuthn bridge with base64url helpers, delegate handling, error mapping, and presentation context provider
- `packages/auth/amplify_auth_cognito/darwin/Classes/AmplifyAuthCognitoPlugin.swift` - Added WebAuthnBridgeImpl creation and WebAuthnBridgeApiSetup.setUp call in register(with:)

## Decisions Made
- Used PigeonError instead of FlutterError for error propagation since the Pigeon-generated wrapError function handles both PigeonError and FlutterError, and PigeonError is the canonical Pigeon error type
- Stored ASAuthorizationController and completion handler as instance properties to prevent ARC deallocation during async ceremony (per research pitfall #1)
- Used isRegistration boolean flag to track ceremony type so error mapping can default to registrationFailed vs assertionFailed appropriately
- Presentation context provider uses modern UIWindowScene approach on iOS and NSApplication.keyWindow on macOS

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Task 1 commit inadvertently included a web bridge file (webauthn_credential_platform_html.dart) that was staged from a previous session. The WebAuthnBridgeImpl.swift content was correctly committed. This does not affect plan correctness.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- iOS/macOS WebAuthn bridge is complete and registered in the plugin
- Ready for Plan 03 (Android bridge) and Plan 04 (Web bridge) execution
- Error codes match the Dart-side WebAuthnErrorCodes contract established in Plan 01

## Self-Check: PASSED

All 2 files verified present (1 created, 1 modified). Both task commits (28e7c97b5, 898ad18de) verified in git log.

---
*Phase: 03-platform-bridges-ios-android-web*
*Completed: 2026-03-09*

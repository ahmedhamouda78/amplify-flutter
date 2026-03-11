---
phase: 06-authenticator-ui-passkey-screens-and-flows
plan: 01
subsystem: ui
tags: [flutter, authenticator, passkey, l10n, webauthn, localization]

# Dependency graph
requires:
  - phase: 05-credential-management-api
    provides: AuthWebAuthnCredential type for PasskeyPromptState
provides:
  - AuthenticatorStep enum values for first-factor selection and passkey prompt
  - ContinueSignInWithFirstFactorSelection and PasskeyPromptState classes
  - PasswordlessSettings model with PasskeyPromptBehavior and PasskeyRegistrationPrompts
  - All passkey-related localized UI strings (8 buttons, 3 titles, 3 messages)
  - ButtonResolver, TitleResolver, MessageResolver passkey methods and switch cases
affects: [06-02, 06-03]

# Tech tracking
tech-stack:
  added: []
  patterns: [authenticator-state-class-pattern, arb-localization-pattern, resolver-pattern]

key-files:
  created:
    - packages/authenticator/amplify_authenticator/lib/src/models/passwordless_settings.dart
  modified:
    - packages/authenticator/amplify_authenticator/lib/src/enums/authenticator_step.dart
    - packages/authenticator/amplify_authenticator/lib/src/state/auth_state.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/button_resolver.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/title_resolver.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/message_resolver.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/src/buttons/buttons_en.arb
    - packages/authenticator/amplify_authenticator/lib/src/l10n/src/titles/titles_en.arb
    - packages/authenticator/amplify_authenticator/lib/src/l10n/src/messages/messages_en.arb
    - packages/authenticator/amplify_authenticator/lib/src/l10n/generated/button_localizations.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/generated/button_localizations_en.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/generated/title_localizations.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/generated/title_localizations_en.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/generated/message_localizations.dart
    - packages/authenticator/amplify_authenticator/lib/src/l10n/generated/message_localizations_en.dart

key-decisions:
  - "Manually updated generated localization files following existing pattern (intl_utils not available)"
  - "All passkey UI strings use sentence-case tone per user decision"

patterns-established:
  - "AuthState subclass pattern: extend UnauthenticatedState with super(step:) and AWSEquatable props"
  - "Resolver pattern: enum type + key class + resolver methods + switch cases"

requirements-completed: [UI-01, UI-03, UI-04]

# Metrics
duration: 2min
completed: 2026-03-10
---

# Phase 06 Plan 01: Foundational Types and Localization Summary

**AuthenticatorStep enum values, state classes, PasswordlessSettings model, and 14 localized passkey UI strings with resolver methods**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-10T21:28:00Z
- **Completed:** 2026-03-10T21:37:12Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments
- Added continueSignInWithFirstFactorSelection and passkeyPrompt to AuthenticatorStep enum
- Created ContinueSignInWithFirstFactorSelection (with Set<AuthFactorType>) and PasskeyPromptState state classes
- Created PasswordlessSettings model with PasskeyPromptBehavior enum and PasskeyRegistrationPrompts class
- Added 8 button strings, 3 title strings, 3 message strings to ARB files, generated localizations, and resolvers
- TitleResolver.resolve() handles new AuthenticatorStep values without throwing StateError

## Task Commits

Each task was committed atomically:

1. **Task 1: Add AuthenticatorStep enum values, AuthState subclasses, and PasswordlessSettings model** - `ab0cff0` (feat)
2. **Task 2: Add passkey localization strings and resolver methods** - `0c8becb` (feat)

## Files Created/Modified
- `packages/authenticator/amplify_authenticator/lib/src/enums/authenticator_step.dart` - Added continueSignInWithFirstFactorSelection and passkeyPrompt enum values
- `packages/authenticator/amplify_authenticator/lib/src/state/auth_state.dart` - Added ContinueSignInWithFirstFactorSelection and PasskeyPromptState classes
- `packages/authenticator/amplify_authenticator/lib/src/models/passwordless_settings.dart` - New file: PasskeyPromptBehavior, PasskeyRegistrationPrompts, PasswordlessSettings
- `packages/authenticator/amplify_authenticator/lib/src/l10n/button_resolver.dart` - Added 8 passkey button resolver entries
- `packages/authenticator/amplify_authenticator/lib/src/l10n/title_resolver.dart` - Added 3 passkey title resolver entries
- `packages/authenticator/amplify_authenticator/lib/src/l10n/message_resolver.dart` - Added 3 passkey message resolver entries
- `packages/authenticator/amplify_authenticator/lib/src/l10n/src/buttons/buttons_en.arb` - Added 8 button ARB entries
- `packages/authenticator/amplify_authenticator/lib/src/l10n/src/titles/titles_en.arb` - Added 3 title ARB entries
- `packages/authenticator/amplify_authenticator/lib/src/l10n/src/messages/messages_en.arb` - Added 3 message ARB entries
- `packages/authenticator/amplify_authenticator/lib/src/l10n/generated/button_localizations.dart` - Added abstract passkey button getters
- `packages/authenticator/amplify_authenticator/lib/src/l10n/generated/button_localizations_en.dart` - Added English passkey button overrides
- `packages/authenticator/amplify_authenticator/lib/src/l10n/generated/title_localizations.dart` - Added abstract passkey title getters
- `packages/authenticator/amplify_authenticator/lib/src/l10n/generated/title_localizations_en.dart` - Added English passkey title overrides
- `packages/authenticator/amplify_authenticator/lib/src/l10n/generated/message_localizations.dart` - Added abstract passkey message getters
- `packages/authenticator/amplify_authenticator/lib/src/l10n/generated/message_localizations_en.dart` - Added English passkey message overrides

## Decisions Made
- Manually updated generated localization files following existing pattern since intl_utils not available in build environment
- All passkey UI strings use sentence-case tone (not Title Case) per user decision

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All foundational types ready for Plan 02 (passkey screens/widgets) and Plan 03 (state machine integration)
- AuthenticatorStep enum values, state classes, and localized strings provide the contracts downstream plans build against

## Self-Check: PASSED

All 6 key files verified present. Both task commits (ab0cff0, 0c8becb) verified in git history.

---
*Phase: 06-authenticator-ui-passkey-screens-and-flows*
*Completed: 2026-03-10*

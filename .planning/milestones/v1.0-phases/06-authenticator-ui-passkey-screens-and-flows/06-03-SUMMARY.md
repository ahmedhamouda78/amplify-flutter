---
phase: 06-authenticator-ui-passkey-screens-and-flows
plan: 03
subsystem: ui
tags: [flutter, authenticator, passkey, webauthn, registration-prompt, bloc]

# Dependency graph
requires:
  - phase: 06-authenticator-ui-passkey-screens-and-flows
    provides: AuthenticatorStep.passkeyPrompt, PasskeyPromptState, PasswordlessSettings, localized strings
  - phase: 05-credential-management-register-list-delete-apis
    provides: associateWebAuthnCredential, listWebAuthnCredentials, isPasskeySupported, AuthWebAuthnCredential
provides:
  - PasskeyPromptForm widget with create/skip/success visual states
  - AuthPasskeyRegister and AuthPasskeySkip bloc events
  - _checkPasskeyRegistrationPrompt logic checking config, platform, existing passkeys
  - _registerPasskey method calling associateWebAuthnCredential with error handling
  - PasswordlessSettings passthrough from Authenticator widget to StateMachineBloc
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [custom-form-state-pattern, bloc-event-dispatch-from-form]

key-files:
  created: []
  modified:
    - packages/authenticator/amplify_authenticator/lib/src/widgets/form.dart
    - packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart
    - packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_event.dart
    - packages/authenticator/amplify_authenticator/lib/src/state/inherited_forms.dart
    - packages/authenticator/amplify_authenticator/lib/amplify_authenticator.dart

key-decisions:
  - "PasskeyPromptForm handles buttons internally (not separate button widgets) for simpler custom layout"
  - "Hub events guarded against PasskeyPromptState to prevent prompt being skipped by signedIn hub event"

patterns-established:
  - "Custom form pattern: extend AuthenticatorForm with empty fields/actions, override build via state class"

requirements-completed: [UI-03, UI-04]

# Metrics
duration: 5min
completed: 2026-03-10
---

# Phase 06 Plan 03: Passkey Registration Prompt and Error Messaging Summary

**PasskeyPromptForm with create/skip/success states, bloc event handlers for passkey registration, and configurable prompt insertion after sign-in/sign-up**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T21:55:15Z
- **Completed:** 2026-03-10T22:00:11Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- PasskeyPromptForm renders three states: initial prompt with fingerprint icon, loading with disabled buttons, and success with credential list
- Bloc wired with _checkPasskeyRegistrationPrompt that checks config enabled, platform support, and no existing passkeys before showing prompt
- _registerPasskey calls associateWebAuthnCredential and shows inline error on failure (not silent skip per user decision)
- Sign-up flow tracking via _isSignUpFlow enables differentiated prompt behavior for afterSignIn vs afterSignUp

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PasskeyPromptForm and register in Authenticator infrastructure** - `9de0ea00b` (feat)
2. **Task 2: Wire passkey registration prompt into bloc and add credential management events** - `167df7176` (feat)

## Files Created/Modified
- `packages/authenticator/amplify_authenticator/lib/src/widgets/form.dart` - Added PasskeyPromptForm with initial/loading/success views
- `packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart` - Added passwordlessSettings, _checkPasskeyRegistrationPrompt, _registerPasskey, event handlers, hub guard
- `packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_event.dart` - Added AuthPasskeyRegister and AuthPasskeySkip events
- `packages/authenticator/amplify_authenticator/lib/src/state/inherited_forms.dart` - Registered passkeyPromptForm, replaced StateError with form return
- `packages/authenticator/amplify_authenticator/lib/amplify_authenticator.dart` - Wired PasskeyPromptForm in InheritedForms, pass passwordlessSettings to bloc, added export

## Decisions Made
- PasskeyPromptForm handles buttons internally rather than using separate button widget classes -- simpler for this custom layout that doesn't follow the standard fields+actions pattern
- Added hub event guard for PasskeyPromptState to prevent the signedIn hub event from skipping the prompt screen (same pattern as VerifyUserFlow guard)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added hub event guard for PasskeyPromptState**
- **Found during:** Task 2
- **Issue:** Hub signedIn event would set AuthenticatedState while user is on passkey prompt, skipping the prompt
- **Fix:** Added PasskeyPromptState check alongside VerifyUserFlow and AttributeVerificationSent guards in _mapHubEvent
- **Files modified:** auth_bloc.dart
- **Committed in:** 167df7176

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential for correct passkey prompt flow. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 06 is now complete: all three plans (foundational types, challenge selection, and passkey prompt) are implemented
- The Authenticator UI fully supports passkey sign-in selection, automatic ceremony, and post-auth registration prompt

## Self-Check: PASSED

All 5 modified files verified present. Both task commits (9de0ea00b, 167df7176) verified in git history.

---
*Phase: 06-authenticator-ui-passkey-screens-and-flows*
*Completed: 2026-03-10*

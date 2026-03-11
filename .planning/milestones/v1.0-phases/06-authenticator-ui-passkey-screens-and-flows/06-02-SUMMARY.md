---
phase: 06-authenticator-ui-passkey-screens-and-flows
plan: 02
subsystem: ui
tags: [flutter, authenticator, passkey, webauthn, factor-selection, passwordless]

# Dependency graph
requires:
  - phase: 06-authenticator-ui-passkey-screens-and-flows
    provides: AuthenticatorStep enum values, ContinueSignInWithFirstFactorSelection state, PasswordlessSettings model, localized button strings
provides:
  - ContinueSignInWithFirstFactorSelectionForm widget with factor selection layout
  - StateMachineBloc wiring for factor selection and passkey ceremony
  - Authenticator passwordlessSettings constructor parameter
  - InheritedForms registration for factor selection form
  - AuthenticatorScreen routing for factor selection and passkey prompt steps
affects: [06-03]

# Tech tracking
tech-stack:
  added: []
  patterns: [custom-form-state-pattern, factor-value-cognito-mapping]

key-files:
  created: []
  modified:
    - packages/authenticator/amplify_authenticator/lib/src/widgets/form.dart
    - packages/authenticator/amplify_authenticator/lib/src/state/inherited_forms.dart
    - packages/authenticator/amplify_authenticator/lib/src/screens/authenticator_screen.dart
    - packages/authenticator/amplify_authenticator/lib/amplify_authenticator.dart
    - packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart

key-decisions:
  - "Used AuthFactorType.value for Cognito factor strings instead of manual mapping"
  - "Form accesses PasswordlessSettings via findAncestorWidgetOfExactType<Authenticator> for simplicity"
  - "passkeyPrompt case in InheritedForms throws StateError as placeholder for Plan 03"

patterns-established:
  - "Custom form state pattern: extend AuthenticatorForm with super._() empty fields/actions, override createState() for custom layout"
  - "Factor selection uses OutlinedButton for passwordless methods, ElevatedButton for password"

requirements-completed: [UI-01, UI-02, UI-04]

# Metrics
duration: 5min
completed: 2026-03-10
---

# Phase 06 Plan 02: Challenge Selection Screen and Passkey Ceremony Wiring Summary

**Factor selection form with inline password + passwordless buttons, StateMachineBloc emission for continueSignInWithFirstFactorSelection, and Authenticator passwordlessSettings constructor parameter**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T21:44:40Z
- **Completed:** 2026-03-10T21:50:38Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Created ContinueSignInWithFirstFactorSelectionForm with username display, inline password field, "or" divider, and passwordless method buttons
- Wired StateMachineBloc to emit ContinueSignInWithFirstFactorSelection state and handle OTP/password steps
- Added passwordlessSettings parameter to Authenticator widget with PasswordlessSettings export
- Registered form in InheritedForms and added routing in AuthenticatorScreen for both new steps

## Task Commits

Each task was committed atomically:

1. **Task 1: Create factor selection form widget and wire into Authenticator infrastructure** - `6d134d195` (feat)
2. **Task 2: Wire StateMachineBloc to emit factor selection state and handle passkey ceremony** - `6bde5f8a2` (feat)

## Files Created/Modified
- `packages/authenticator/amplify_authenticator/lib/src/widgets/form.dart` - Added ContinueSignInWithFirstFactorSelectionForm with custom stateful build for factor selection layout
- `packages/authenticator/amplify_authenticator/lib/src/state/inherited_forms.dart` - Registered form, added switch cases for continueSignInWithFirstFactorSelection and passkeyPrompt
- `packages/authenticator/amplify_authenticator/lib/src/screens/authenticator_screen.dart` - Added routing cases for new steps in builder and tabTitle extension
- `packages/authenticator/amplify_authenticator/lib/amplify_authenticator.dart` - Added passwordlessSettings parameter, PasswordlessSettings export, form wiring in InheritedForms
- `packages/authenticator/amplify_authenticator/lib/src/blocs/auth/auth_bloc.dart` - Replaced TODO with proper state emissions in both _confirmSignIn and _processSignInResult

## Decisions Made
- Used AuthFactorType.value property for Cognito factor string mapping instead of manual switch (cleaner, matches enum definition)
- Form accesses PasswordlessSettings via context.findAncestorWidgetOfExactType<Authenticator>() rather than creating a new InheritedWidget (simpler, sufficient for this use case)
- passkeyPrompt case in InheritedForms operator[] throws StateError as placeholder -- Plan 03 will register the actual form

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Dart SDK not available in build environment for static analysis verification; verified code correctness by pattern matching against existing codebase and checking all import paths

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Factor selection form and bloc wiring complete, ready for Plan 03 (passkey registration prompt)
- passkeyPrompt placeholder in InheritedForms awaiting Plan 03 implementation
- All passkey ceremony errors flow through existing exception banner system

## Self-Check: PASSED

All 5 modified files verified present. Both task commits (6d134d195, 6bde5f8a2) verified in git history. Key content (form widget, InheritedForms registration, screen routing, passwordlessSettings, bloc wiring) verified in files.

---
*Phase: 06-authenticator-ui-passkey-screens-and-flows*
*Completed: 2026-03-10*

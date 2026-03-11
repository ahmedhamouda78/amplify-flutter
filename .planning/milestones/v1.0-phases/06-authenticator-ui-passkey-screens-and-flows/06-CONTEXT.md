# Phase 6: Authenticator UI — Passkey Screens and Flows - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Integrate passkey support into the pre-built Authenticator widget. Four requirements: challenge selection screen (UI-01), passkey ceremony flow (UI-02), post-auth registration prompt (UI-03), user-friendly error messages (UI-04). This phase modifies the Authenticator package only — all auth plugin APIs and platform bridges are already complete from Phases 1-5.

</domain>

<decisions>
## Implementation Decisions

### Challenge Selection Screen (UI-01) — Match React's SignInSelectAuthFactor

- **Layout matches React**: Username (read-only) at top. If PASSWORD is available: inline password field + "Sign in with Password" submit button, divider ("or"), then passwordless method buttons below (one per method). Each passwordless button is a full-width tappable button that immediately selects that method.
- **Button labels**: "Sign in with Passkey", "Sign in with Password", "Sign in with Email", "Sign in with SMS" — adapted for Flutter's existing Authenticator tone (sentence case, not Title Case)
- **Back to Sign In** link at the bottom of the selection screen
- **Hide unsupported methods**: If `isPasskeySupported()` returns false, hide the passkey button entirely (don't show disabled)
- **New `AuthenticatorStep`**: Add `continueSignInWithFirstFactorSelection` to the `AuthenticatorStep` enum
- **New form**: `ContinueSignInWithFirstFactorSelectionForm` with the React-matching layout
- **New auth state**: `ContinueSignInWithFirstFactorSelection` state class carrying `Set<AuthFactorType> availableFactors`

### Modified Sign-In Screen — Preferred Challenge + Other Options

- **Modify existing sign-in screen**: When a `preferredChallenge` is configured and multiple auth methods are available, the sign-in screen primary button text changes to match the preferred method (e.g., "Sign in with Passkey")
- **Hide password field when passwordless preferred**: If `preferredChallenge` is `WEB_AUTHN`, `EMAIL_OTP`, or `SMS_OTP`, hide the password field and only show username + preferred method button + "Other sign-in options" link
- **"Other sign-in options" link**: Shown below the primary button when multiple auth methods exist. Tapping navigates to the factor selection screen (above)
- **Config source**: Read `preferredChallenge` from `amplify_outputs.json` auth config by default, allow developer override via Authenticator constructor parameter

### PasswordlessSettings Authenticator Prop — Match React

- **New `PasswordlessSettings` class** added as a constructor parameter on the `Authenticator` widget, matching React's shape:
  - `hiddenAuthMethods: List<AuthFactorType>?` — factors to hide from selection
  - `preferredAuthMethod: AuthFactorType?` — preferred challenge override (overrides amplify_outputs config)
  - `passkeyRegistrationPrompts: PasskeyRegistrationPrompts?` — controls post-auth registration prompt
- **`PasskeyRegistrationPrompts`**: Can be a simple `bool` (enable/disable all) or structured with `afterSignIn: PasskeyPromptBehavior` and `afterSignUp: PasskeyPromptBehavior` where behavior is `always` or `never`
- **`passkeyRegistrationPrompts` is prop-only** — not read from `amplify_outputs.json` (not in the schema)
- **`hiddenAuthMethods` and `preferredAuthMethod` override** what's in `amplify_outputs.json`

### Passkey Registration Prompt (UI-03) — Match React's PasskeyPrompt

- **Prompt trigger**: After successful sign-in or sign-up, if `passkeyRegistrationPrompts` config says to prompt AND user has no existing passkeys (checked via `listWebAuthnCredentials()`), show the registration prompt screen
- **Prompt layout**: Heading ("Sign in faster with a passkey"), description text, passkey icon, "Create a passkey" primary button, "Continue without a passkey" skip link
- **Registration flow**: Tapping "Create a passkey" calls `associateWebAuthnCredential()` which triggers the platform ceremony
- **Success state**: After successful registration, show success checkmark, list existing passkeys, "Set up another passkey" link, "Continue" primary button
- **Cancel/error behavior**: If user cancels the platform ceremony or registration fails, show error message on the prompt screen. User can retry ("Create a passkey") or skip ("Continue without a passkey"). Does NOT silently skip.
- **Skip behavior**: "Continue without a passkey" proceeds directly to authenticated state

### Passkey Ceremony Flow (UI-02)

- **Auto-trigger on selection**: When user selects passkey on the factor selection screen, the bloc calls `confirmSignIn(challengeResponse: 'WEB_AUTHN')`. The state machine handles the `WEB_AUTHN` challenge automatically (platform ceremony triggers without additional UI)
- **Loading state**: Show loading indicator while the platform ceremony is in progress
- **Success**: On ceremony completion, sign-in completes and user reaches authenticated state (or registration prompt if configured)

### Error Messaging (UI-04)

- **Sign-in errors**: Show error as a banner on the factor selection screen. User stays on selection screen and can retry passkey or pick another method. Matches existing MFA error pattern.
- **Registration prompt errors**: Show error message inline on the prompt screen. User can retry or skip.
- **Localization**: All passkey strings added to the existing `AuthStringResolver` system (ButtonResolver, TitleResolver, MessageResolver, InstructionsResolver). Developers can override via custom resolvers.
- **String style**: Adapt React's text for Flutter conventions (sentence case, match existing Authenticator tone) rather than copying React strings verbatim

### Claude's Discretion

- Exact widget tree structure and composition for new forms
- Internal state management details (bloc event types, state transitions)
- Form field widget implementations
- `isPasskeySupported()` check timing and caching strategy
- Test structure and mock strategies
- Exact string wording (adapted from React's defaults for Flutter tone)
- How `hiddenAuthMethods` filters the available factors list

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `StateMachineBloc` (auth_bloc.dart): Central state machine — lines 264-276 have the TODO placeholder to replace
- `_processSignInResult()` (auth_bloc.dart:335-380): Handles sign-in step routing — needs `continueSignInWithFirstFactorSelection` case
- `AuthenticatorStep` enum (authenticator_step.dart): Add new step for factor selection
- `AuthState` / `UnauthenticatedState` (auth_state.dart): Pattern for new state classes (see `ContinueSignInWithMfaSelection` as model)
- `InheritedForms` (inherited_forms.dart): Form registration — add new form for factor selection
- `AuthenticatorScreen` (authenticator_screen.dart): Screen routing — add case for new step
- `ContinueSignInWithMfaSelectionForm` (form.dart:554-568): Closest existing pattern — radio buttons + Continue
- `AmplifyAuthService` (amplify_auth_service.dart): Auth service abstraction — may need methods for passkey operations
- `AuthStringResolver` with ButtonResolver, TitleResolver, MessageResolver, InstructionsResolver: Localization system
- `InheritedConfig` (inherited_config.dart): Provides amplify_outputs config to widgets

### Key Integration Points
- `auth_bloc.dart:264-276`: Replace "Passwordless is not supported" with factor selection state
- `auth_bloc.dart:335-380` (`_processSignInResult`): Add `continueSignInWithFirstFactorSelection` handling
- `Authenticator` constructor: Add `passwordless` parameter (PasswordlessSettings)
- `InheritedForms`: Add `continueSignInWithFirstFactorSelectionForm` + `passkeyPromptForm`
- `AuthenticatorStep` enum: Add new steps
- `AuthenticatorScreen.builder()`: Add switch cases for new steps
- Sign-in form: Modify to support preferred challenge button + "Other sign-in options"
- `AuthNextSignInStep.availableFactors`: Already carries `Set<AuthFactorType>` for factor selection

### React Reference (amplify-ui)
- `SignInSelectAuthFactor.tsx`: Factor selection with inline password + passwordless buttons
- `PasskeyPrompt.tsx`: Registration prompt with create/skip/success states
- `SignIn.tsx`: Modified sign-in with preferredChallenge button + "Other sign-in options"
- `PasswordlessSettings` type: `{ hiddenAuthMethods, preferredAuthMethod, passkeyRegistrationPrompts }`
- `guards.ts`: `shouldPromptPasskeyRegistration` — checks config + existing passkeys

</code_context>

<specifics>
## Specific Ideas

- React uses separate routes for `signInSelectAuthFactor` and `passkeyPrompt` — Flutter should add corresponding `AuthenticatorStep` values and form widgets
- React's `SignIn` component checks `availableAuthMethods.length > 1` to decide whether to show "Other sign-in options" — Flutter should check the same
- React's `PasskeyPrompt` calls `listWebAuthnCredentials()` after successful registration to show the list — Flutter should do the same via `Amplify.Auth.listWebAuthnCredentials()`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-authenticator-ui-passkey-screens-and-flows*
*Context gathered: 2026-03-10*

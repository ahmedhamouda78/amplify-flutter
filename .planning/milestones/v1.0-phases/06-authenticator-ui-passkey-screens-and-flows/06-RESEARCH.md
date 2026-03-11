# Phase 6: Authenticator UI — Passkey Screens and Flows - Research

**Researched:** 2026-03-10
**Domain:** Flutter UI integration for passkey authentication
**Confidence:** HIGH

## Summary

Phase 6 integrates passkey support into the existing Authenticator widget. The Authenticator package uses a StateMachineBloc architecture with distinct states, forms, and screen routing. Integration requires adding new AuthenticatorStep enums, AuthState subclasses, Form widgets, and screen routing cases — all following established patterns from MFA selection (ContinueSignInWithMfaSelection) which serves as the closest reference implementation.

The existing architecture is well-documented in code. React's amplify-ui provides reference UI patterns for SignInSelectAuthFactor (challenge selection) and PasskeyPrompt (registration prompt). All required auth plugin APIs (associateWebAuthnCredential, listWebAuthnCredentials, isPasskeySupported) are already complete from Phase 5.

**Primary recommendation:** Follow the ContinueSignInWithMfaSelection pattern exactly — state class carrying Set<AuthFactorType>, form with radio buttons + submit, bloc case returning the state, InheritedForms registration, AuthenticatorScreen routing, and localization via ButtonResolver/TitleResolver extensions.

## User Constraints

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Challenge Selection Screen (UI-01) — Match React's SignInSelectAuthFactor**
- Layout matches React: Username (read-only) at top. If PASSWORD is available: inline password field + "Sign in with Password" submit button, divider ("or"), then passwordless method buttons below (one per method). Each passwordless button is a full-width tappable button that immediately selects that method.
- Button labels: "Sign in with Passkey", "Sign in with Password", "Sign in with Email", "Sign in with SMS" — adapted for Flutter's existing Authenticator tone (sentence case, not Title Case)
- Back to Sign In link at the bottom of the selection screen
- Hide unsupported methods: If `isPasskeySupported()` returns false, hide the passkey button entirely (don't show disabled)
- New `AuthenticatorStep`: Add `continueSignInWithFirstFactorSelection` to the `AuthenticatorStep` enum
- New form: `ContinueSignInWithFirstFactorSelectionForm` with the React-matching layout
- New auth state: `ContinueSignInWithFirstFactorSelection` state class carrying `Set<AuthFactorType> availableFactors`

**Modified Sign-In Screen — Preferred Challenge + Other Options**
- Modify existing sign-in screen: When a `preferredChallenge` is configured and multiple auth methods are available, the sign-in screen primary button text changes to match the preferred method (e.g., "Sign in with Passkey")
- Hide password field when passwordless preferred: If `preferredChallenge` is `WEB_AUTHN`, `EMAIL_OTP`, or `SMS_OTP`, hide the password field and only show username + preferred method button + "Other sign-in options" link
- "Other sign-in options" link: Shown below the primary button when multiple auth methods exist. Tapping navigates to the factor selection screen (above)
- Config source: Read `preferredChallenge` from `amplify_outputs.json` auth config by default, allow developer override via Authenticator constructor parameter

**PasswordlessSettings Authenticator Prop — Match React**
- New `PasswordlessSettings` class added as a constructor parameter on the `Authenticator` widget, matching React's shape:
  - `hiddenAuthMethods: List<AuthFactorType>?` — factors to hide from selection
  - `preferredAuthMethod: AuthFactorType?` — preferred challenge override (overrides amplify_outputs config)
  - `passkeyRegistrationPrompts: PasskeyRegistrationPrompts?` — controls post-auth registration prompt
- `PasskeyRegistrationPrompts`: Can be a simple `bool` (enable/disable all) or structured with `afterSignIn: PasskeyPromptBehavior` and `afterSignUp: PasskeyPromptBehavior` where behavior is `always` or `never`
- `passkeyRegistrationPrompts` is prop-only — not read from `amplify_outputs.json` (not in the schema)
- `hiddenAuthMethods` and `preferredAuthMethod` override what's in `amplify_outputs.json`

**Passkey Registration Prompt (UI-03) — Match React's PasskeyPrompt**
- Prompt trigger: After successful sign-in or sign-up, if `passkeyRegistrationPrompts` config says to prompt AND user has no existing passkeys (checked via `listWebAuthnCredentials()`), show the registration prompt screen
- Prompt layout: Heading ("Sign in faster with a passkey"), description text, passkey icon, "Create a passkey" primary button, "Continue without a passkey" skip link
- Registration flow: Tapping "Create a passkey" calls `associateWebAuthnCredential()` which triggers the platform ceremony
- Success state: After successful registration, show success checkmark, list existing passkeys, "Set up another passkey" link, "Continue" primary button
- Cancel/error behavior: If user cancels the platform ceremony or registration fails, show error message on the prompt screen. User can retry ("Create a passkey") or skip ("Continue without a passkey"). Does NOT silently skip.
- Skip behavior: "Continue without a passkey" proceeds directly to authenticated state

**Passkey Ceremony Flow (UI-02)**
- Auto-trigger on selection: When user selects passkey on the factor selection screen, the bloc calls `confirmSignIn(challengeResponse: 'WEB_AUTHN')`. The state machine handles the `WEB_AUTHN` challenge automatically (platform ceremony triggers without additional UI)
- Loading state: Show loading indicator while the platform ceremony is in progress
- Success: On ceremony completion, sign-in completes and user reaches authenticated state (or registration prompt if configured)

**Error Messaging (UI-04)**
- Sign-in errors: Show error as a banner on the factor selection screen. User stays on selection screen and can retry passkey or pick another method. Matches existing MFA error pattern.
- Registration prompt errors: Show error message inline on the prompt screen. User can retry or skip.
- Localization: All passkey strings added to the existing `AuthStringResolver` system (ButtonResolver, TitleResolver, MessageResolver, InstructionsResolver). Developers can override via custom resolvers.
- String style: Adapt React's text for Flutter conventions (sentence case, match existing Authenticator tone) rather than copying React strings verbatim

### Claude's Discretion

- Exact widget tree structure and composition for new forms
- Internal state management details (bloc event types, state transitions)
- Form field widget implementations
- `isPasskeySupported()` check timing and caching strategy
- Test structure and mock strategies
- Exact string wording (adapted from React's defaults for Flutter tone)
- How `hiddenAuthMethods` filters the available factors list

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-01 | Challenge selection screen when `AuthSignInStep.continueSignInWithFirstFactorSelection` is returned | StateMachineBloc pattern (lines 264-276 replacement), ContinueSignInWithMfaSelection as reference, React's SignInSelectAuthFactor for layout |
| UI-02 | Passkey sign-in flow end-to-end: user selects passkey → ceremony triggers → sign-in completes or error shown | confirmSignIn with 'WEB_AUTHN' response, loading state pattern from existing forms, error banner system already in place |
| UI-03 | Optional passkey registration prompt after sign-in/sign-up (configurable via PasswordlessSettings) | React's PasskeyPrompt pattern, _checkUserVerification flow as insertion point, associateWebAuthnCredential + listWebAuthnCredentials APIs |
| UI-04 | User-friendly error messages for passkey failures with recovery suggestions | AuthStringResolver system (ButtonResolver, MessageResolver), existing banner system via AuthenticatorException, React strings as reference |
</phase_requirements>

## Standard Stack

### Core Components
| Component | Location | Purpose | Why Standard |
|-----------|----------|---------|--------------|
| StateMachineBloc | auth_bloc.dart | Central state machine handling auth flow | Core Authenticator architecture — all auth flows go through this |
| AuthenticatorStep enum | authenticator_step.dart | Defines available UI steps | Standard pattern — add new steps here for routing |
| AuthState subclasses | auth_state.dart | Carries state-specific data | UnauthenticatedState pattern used for all intermediate steps |
| InheritedForms | inherited_forms.dart | Form registration and routing | All forms must register here for step-based rendering |
| AuthenticatorScreen | authenticator_screen.dart | Screen routing logic | Switch-case pattern routes steps to forms |
| AuthStringResolver | auth_strings_resolver.dart | Localization system | Standard localization — ButtonResolver, TitleResolver, MessageResolver |
| AuthenticatorForm | form.dart | Base form class | All custom forms extend this with fields + actions |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK | Widget testing | All UI tests |
| amplify_authenticator_test | workspace | Test utilities (MockAuthenticatorApp, page objects) | Integration tests for flows |
| amplify_integration_test | workspace | Test infrastructure | Mocking auth plugin |

### Reference Implementations
| Pattern | Flutter Example | React Reference | Use For |
|---------|----------------|-----------------|---------|
| Factor selection | ContinueSignInWithMfaSelection (lines 109-121 auth_state.dart, lines 554-568 form.dart) | SignInSelectAuthFactor.tsx | UI-01 challenge selection screen |
| Post-auth flow | _checkUserVerification (lines 437-454 auth_bloc.dart) | shouldPromptPasskeyRegistration guard | UI-03 registration prompt insertion point |
| Error banners | AuthenticatorException + _showExceptionBanner | RemoteErrorMessage component | UI-04 error messaging |
| Loading states | isPending pattern in existing forms | isRegistering state in PasskeyPrompt | UI-02 ceremony loading state |

**Installation:**
```bash
# No new dependencies — all functionality uses existing Authenticator architecture
```

## Architecture Patterns

### Recommended Integration Points

**1. StateMachineBloc (auth_bloc.dart)**
```
Lines 264-276: Replace "Passwordless is not supported" with continueSignInWithFirstFactorSelection handling
Lines 335-380 (_processSignInResult): Add continueSignInWithFirstFactorSelection case
Lines 437-454 (_checkUserVerification): Insert registration prompt logic before AuthenticatedState
```

**2. State Classes (auth_state.dart)**
```dart
// Add after ContinueSignInWithMfaSelection (line 122)
class ContinueSignInWithFirstFactorSelection extends UnauthenticatedState {
  const ContinueSignInWithFirstFactorSelection({
    Set<AuthFactorType>? availableFactors,
  }) : availableFactors = availableFactors ?? const {},
       super(step: AuthenticatorStep.continueSignInWithFirstFactorSelection);

  final Set<AuthFactorType> availableFactors;

  @override
  List<Object?> get props => [step, availableFactors];

  @override
  String get runtimeTypeName => 'ContinueSignInWithFirstFactorSelection';
}
```

**3. Authenticator Step Enum (authenticator_step.dart)**
```dart
// Add after line 105
/// The user is on the Continue Sign In with First Factor Selection step.
/// The sign-in is not complete and the user must select a first-factor method.
continueSignInWithFirstFactorSelection,
```

**4. Form Pattern (form.dart)**
```dart
// Follow ContinueSignInWithMfaSelectionForm pattern (lines 554-568)
class ContinueSignInWithFirstFactorSelectionForm extends AuthenticatorForm {
  ContinueSignInWithFirstFactorSelectionForm({super.key})
    : super._(
        fields: [ConfirmSignInFormField.firstFactorSelection()],
        actions: const [
          ContinueSignInFirstFactorSelectionButton(),
          BackToSignInButton(),
        ],
      );

  @override
  AuthenticatorFormState<ContinueSignInWithFirstFactorSelectionForm> createState() =>
      AuthenticatorFormState<ContinueSignInWithFirstFactorSelectionForm>();
}
```

**5. InheritedForms Registration (inherited_forms.dart)**
```dart
// Add constructor parameter (line 27):
required this.continueSignInWithFirstFactorSelectionForm,

// Add field (line 45):
final ContinueSignInWithFirstFactorSelectionForm
  continueSignInWithFirstFactorSelectionForm;

// Add switch case in operator[] (line 63):
case AuthenticatorStep.continueSignInWithFirstFactorSelection:
  return continueSignInWithFirstFactorSelectionForm;

// Add to updateShouldNotify (line 126):
oldWidget.continueSignInWithFirstFactorSelectionForm !=
    continueSignInWithFirstFactorSelectionForm;
```

**6. Screen Routing (authenticator_screen.dart)**
```dart
// Add to switch case (line 106):
case AuthenticatorStep.continueSignInWithFirstFactorSelection:
  child = _FormWrapperView(step: step);
```

**7. Authenticator Constructor (amplify_authenticator.dart)**
```dart
// Add parameter around line 320:
this.passwordlessSettings,

// Add field around line 440:
/// Configuration for passwordless authentication options.
final PasswordlessSettings? passwordlessSettings;

// Pass to InheritedConfig or store in state as needed
```

### Pattern: Challenge Selection with Inline Password

**What:** React's SignInSelectAuthFactor shows username (read-only), optional inline password field + submit, divider, then passwordless method buttons.

**When to use:** When `AuthSignInStep.continueSignInWithFirstFactorSelection` is returned with multiple `availableFactors`.

**Implementation approach:**
1. Check if PASSWORD is in availableFactors — if yes, show password field + submit button
2. Filter passwordless methods (EMAIL_OTP, SMS_OTP, WEB_AUTHN)
3. Show divider only if both password and passwordless methods exist
4. Map each passwordless method to full-width button with immediate selection
5. Hide WEB_AUTHN button if `isPasskeySupported()` returns false

**Reference:**
```typescript
// React: SignInSelectAuthFactor.tsx lines 66-68
const methods = (availableAuthMethods ?? []) as AuthMethod[];
const hasPassword = methods.includes('PASSWORD');
const passwordlessMethods = methods.filter((m) => m !== 'PASSWORD');
```

### Pattern: Passkey Registration Prompt

**What:** Post-authentication prompt offering passkey registration, with create/skip options and success state.

**When to use:** After successful sign-in or sign-up, if `passkeyRegistrationPrompts` config allows AND user has zero existing passkeys.

**Implementation approach:**
1. Insert check in `_checkUserVerification` before yielding AuthenticatedState
2. Check passkeyRegistrationPrompts config (afterSignIn / afterSignUp)
3. Call `listWebAuthnCredentials()` — if empty and prompt enabled, yield PasskeyPromptState
4. Form shows heading, description, icon, "Create a passkey" button, "Continue without a passkey" link
5. On button tap, call `associateWebAuthnCredential()` with loading state
6. On success, show success view with credential list + "Set up another passkey" link + "Continue" button
7. On cancel/error, show error inline, allow retry or skip
8. On skip, proceed to AuthenticatedState

**Reference:**
```typescript
// React: PasskeyPrompt.tsx lines 73-102
const handleRegister = async () => {
  try {
    setError(null);
    setIsRegistering(true);
    await associateWebAuthnCredential();
    setSuccess(true);
  } catch (err) {
    // Handle cancel vs error
  }
};
```

### Pattern: Localization Extensions

**What:** Add passkey-specific strings to existing resolver system.

**When to use:** All user-facing text (buttons, titles, messages, instructions).

**Implementation approach:**
1. Add enum values to ButtonResolverKeyType (signInWithPasskey, createPasskey, continueWithoutPasskey, setupAnotherPasskey, otherSignInOptions)
2. Add methods to ButtonResolver returning localized strings
3. Add enum values to TitleResolverKeyType (passkeyPrompt, passkeyCreatedSuccess)
4. Add methods to TitleResolver
5. Add enum values to MessageResolverKeyType (passkeyRegistrationFailed, existingPasskeys)
6. Update generated localizations files (button_localizations_en.dart, etc.)
7. Adapt React strings to Flutter tone (sentence case, simpler phrasing)

**Flutter tone examples:**
- React: "Sign In with Passkey" → Flutter: "Sign in with passkey"
- React: "Create a Passkey" → Flutter: "Create a passkey"
- React: "Continue Without a Passkey" → Flutter: "Continue without a passkey"

### Anti-Patterns to Avoid

- **Hardcoded strings**: ALL user-facing text must go through AuthStringResolver for localization
- **Direct Amplify.Auth calls in widgets**: Use AuthenticatorState methods or bloc events
- **State mutations**: AuthState subclasses are immutable — bloc yields new states
- **Skipping InheritedForms registration**: Forms won't render without operator[] case
- **Ignoring platform capability**: Always check `isPasskeySupported()` before showing passkey UI

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| State management for auth flows | Custom state machine or provider | StateMachineBloc + AuthState subclasses | Existing architecture handles hub events, exceptions, loading states, and step transitions |
| Form layout and field management | Custom form widgets from scratch | AuthenticatorForm._ constructor with fields + actions | Standardized pattern with field validation, error display, and action button placement |
| Screen routing | Navigator push/pop or PageView | AuthenticatorStep enum + InheritedForms operator[] + AuthenticatorScreen switch | Declarative routing tied to auth state — back navigation handled automatically |
| Localization | Intl package directly or hardcoded strings | AuthStringResolver system (ButtonResolver, TitleResolver, MessageResolver) | Integrated with Flutter's localization, overridable by developers, generated files for type safety |
| Error banners | SnackBar / MaterialBanner manually | AuthenticatorException with showBanner flag | Consistent error display across all flows, respects exceptionBannerLocation config |
| Loading states | Custom CircularProgressIndicator logic | isPending pattern from bloc stream + isDisabled on buttons | Consistent loading UX, prevents double-submission, integrated with bloc |
| Config reading | Manual AmplifyOutputs parsing | InheritedConfig.of(context).amplifyOutputs | Ensures config is loaded before widget build, handles config errors centrally |

**Key insight:** The Authenticator package has mature patterns for every UI concern (state, forms, routing, localization, errors, loading). Deviating from these patterns creates maintenance burden and breaks developer customization (e.g., custom string resolvers, custom forms).

## Common Pitfalls

### Pitfall 1: Forgetting to Update All Integration Points

**What goes wrong:** Adding AuthenticatorStep enum but forgetting InheritedForms operator[] case causes runtime exception when step is emitted.

**Why it happens:** Five separate files require updates for a new step (enum, state, forms, inherited_forms, screen routing). Missing one breaks the chain.

**How to avoid:** Use checklist for every new step:
1. ✓ AuthenticatorStep enum value (authenticator_step.dart)
2. ✓ AuthState subclass (auth_state.dart)
3. ✓ Form widget (form.dart)
4. ✓ InheritedForms constructor param + field + operator[] + updateShouldNotify (inherited_forms.dart)
5. ✓ AuthenticatorScreen switch case (authenticator_screen.dart)
6. ✓ StateMachineBloc yield cases (auth_bloc.dart: _confirmSignIn and _processSignInResult)

**Warning signs:** "RangeError (index): Invalid value: Not in inclusive range" when form is supposed to display.

### Pitfall 2: Incorrect State Class Hierarchy

**What goes wrong:** Making new state class extend AuthState directly instead of UnauthenticatedState breaks step property access.

**Why it happens:** Looking at ConfirmSignInCustom (line 97-107 auth_state.dart) which extends UnauthenticatedState, but forgetting this is the pattern.

**How to avoid:** All intermediate auth states (not LoadingState or AuthenticatedState) MUST extend UnauthenticatedState with required step parameter. Check ContinueSignInWithMfaSelection (lines 109-121) as template.

**Warning signs:** Compiler error "The getter 'step' isn't defined for the type 'NewState'" when AuthenticatorScreen tries to route.

### Pitfall 3: Not Handling Platform Unsupported Case

**What goes wrong:** Showing passkey button on platforms where `isPasskeySupported()` returns false leads to confusing errors when user taps it.

**Why it happens:** Assuming passkey is always available because Phase 1-5 implemented it.

**How to avoid:**
1. Call `isPasskeySupported()` in form's initState or build
2. Filter WEB_AUTHN from availableFactors if unsupported
3. Don't show passkey button if WEB_AUTHN not in filtered list
4. Cache the result — don't call on every build

**Warning signs:** User taps "Sign in with passkey" → platform ceremony fails immediately with "not supported" error instead of button being hidden.

### Pitfall 4: Silent Skip on Passkey Registration Cancel

**What goes wrong:** React's PasskeyPrompt silently skips on cancel (lines 85-95). User context says "Does NOT silently skip" — show error and allow retry.

**Why it happens:** Copying React code without reading CONTEXT.md decisions.

**How to avoid:** On `PasskeyRegistrationCanceled` or similar error from `associateWebAuthnCredential()`, show error message on prompt screen with "Create a passkey" (retry) and "Continue without a passkey" (skip) options. Only skip if user explicitly taps skip link.

**Warning signs:** User cancels platform passkey dialog → prompt disappears without explanation → user confused about what happened.

### Pitfall 5: Wrong PasswordlessSettings Config Reading

**What goes wrong:** Reading `passkeyRegistrationPrompts` from `amplify_outputs.json` when user context says "prop-only — not read from amplify_outputs.json".

**Why it happens:** Seeing `preferredAuthMethod` can be overridden from outputs and assuming same for prompts.

**How to avoid:**
- `preferredAuthMethod`: Read from amplify_outputs.auth.preferredChallenge, allow Authenticator.passwordlessSettings override
- `hiddenAuthMethods`: Prop-only override, filter on top of outputs config
- `passkeyRegistrationPrompts`: Prop-only, NOT in amplify_outputs schema

**Warning signs:** Integration tests fail because prompts don't appear when expected — config parsing tries to read non-existent JSON field.

### Pitfall 6: Bloc State Yield Order

**What goes wrong:** Yielding registration prompt state before calling `listWebAuthnCredentials()` causes form to render before data is ready.

**Why it happens:** Async operations in bloc streams require careful ordering.

**How to avoid:** In `_checkUserVerification`, check prompt config and call `listWebAuthnCredentials()` BEFORE yielding PasskeyPromptState. Pass credential list as state property if needed, or have form call it in initState (but then loading state needed).

**Warning signs:** Form displays "You have 0 passkeys" then suddenly updates to "You have 2 passkeys" — flicker indicates async timing issue.

## Code Examples

Verified patterns from codebase:

### Creating a New AuthState Subclass
```dart
// Source: auth_state.dart lines 109-121 (ContinueSignInWithMfaSelection pattern)
class ContinueSignInWithFirstFactorSelection extends UnauthenticatedState {
  const ContinueSignInWithFirstFactorSelection({
    Set<AuthFactorType>? availableFactors,
  }) : availableFactors = availableFactors ?? const {},
       super(step: AuthenticatorStep.continueSignInWithFirstFactorSelection);

  final Set<AuthFactorType> availableFactors;

  @override
  List<Object?> get props => [step, availableFactors];

  @override
  String get runtimeTypeName => 'ContinueSignInWithFirstFactorSelection';
}
```

### Yielding State in StateMachineBloc
```dart
// Source: auth_bloc.dart lines 232-235 (continueSignInWithMfaSelection case)
case AuthSignInStep.continueSignInWithFirstFactorSelection:
  yield ContinueSignInWithFirstFactorSelection(
    availableFactors: result.nextStep.availableFactors,
  );
```

### Form with Fields and Actions
```dart
// Source: form.dart lines 554-568 (MFA selection pattern)
class ContinueSignInWithFirstFactorSelectionForm extends AuthenticatorForm {
  ContinueSignInWithFirstFactorSelectionForm({super.key})
    : super._(
        fields: [ConfirmSignInFormField.firstFactorSelection()],
        actions: const [
          ContinueSignInFirstFactorSelectionButton(),
          BackToSignInButton(),
        ],
      );

  @override
  AuthenticatorFormState<ContinueSignInWithFirstFactorSelectionForm> createState() =>
      AuthenticatorFormState<ContinueSignInWithFirstFactorSelectionForm>();
}
```

### Checking Platform Support Before Showing UI
```dart
// Pattern for filtering factors based on platform capability
Future<Set<AuthFactorType>> _getAvailableFactors(
  Set<AuthFactorType> factors,
) async {
  final filtered = Set<AuthFactorType>.from(factors);

  // Hide passkey if platform doesn't support it
  if (filtered.contains(AuthFactorType.webAuthn)) {
    final supported = await Amplify.Auth.isPasskeySupported();
    if (!supported) {
      filtered.remove(AuthFactorType.webAuthn);
    }
  }

  return filtered;
}
```

### Inserting Registration Prompt in Auth Flow
```dart
// Source: auth_bloc.dart lines 437-454 (_checkUserVerification pattern)
Stream<AuthState> _checkPasskeyRegistrationPrompt() async* {
  try {
    // Check config (simplified — actual implementation reads from widget)
    final promptConfig = _passwordlessSettings?.passkeyRegistrationPrompts;
    if (promptConfig == null || promptConfig == false) {
      yield const AuthenticatedState();
      return;
    }

    // Check existing passkeys
    final credentials = await Amplify.Auth.listWebAuthnCredentials();
    if (credentials.isEmpty) {
      yield PasskeyPromptState();
    } else {
      yield const AuthenticatedState();
    }
  } on Exception catch (e) {
    _exceptionController.add(AuthenticatorException(e, showBanner: false));
    yield const AuthenticatedState();
  }
}
```

### Localization Extension
```dart
// Add to ButtonResolver
String signInWithPasskey(BuildContext context) {
  return AuthenticatorLocalizations.buttonsOf(context).signInWithPasskey;
}

String otherSignInOptions(BuildContext context) {
  return AuthenticatorLocalizations.buttonsOf(context).otherSignInOptions;
}

// Update resolve method
case ButtonResolverKeyType.signInWithPasskey:
  return signInWithPasskey(context);
case ButtonResolverKeyType.otherSignInOptions:
  return otherSignInOptions(context);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Passwordless not supported placeholder | Full passkey factor selection + registration UI | Phase 6 (2026-03-10) | Lines 264-276 auth_bloc.dart replaced with actual implementation |
| MFA-only selection screens | First-factor selection with PASSWORD + passwordless methods | React amplify-ui v6+ pattern | Unified selection screen for all first-factor methods |
| No registration prompts | Post-auth passkey registration prompt | React amplify-ui passkey feature | Increases passkey adoption by prompting after successful auth |

**Deprecated/outdated:**
- TODO comment at lines 264-276 auth_bloc.dart: "Passwordless is not supported" — replaced by factor selection flow
- Assumption that SELECT_CHALLENGE only used for MFA — now used for first-factor selection too

## Open Questions

None — all research domains fully covered. User decisions from CONTEXT.md provide clear direction for all requirements.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + amplify_authenticator_test (workspace package) |
| Config file | none — test infrastructure in workspace package |
| Quick run command | `flutter test test/ui-01_factor_selection_test.dart --reporter compact` |
| Full suite command | `flutter test packages/authenticator/amplify_authenticator/test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | Challenge selection shows available factors, hides unsupported passkey, allows selection | widget | `flutter test test/factor_selection_screen_test.dart --name "challenge selection"` | ❌ Wave 0 |
| UI-02 | Passkey selection triggers ceremony, shows loading, handles success/error | integration | `flutter test test/passkey_signin_flow_test.dart --name "ceremony flow"` | ❌ Wave 0 |
| UI-03 | Registration prompt shows after auth if config enabled, handles create/skip/retry | integration | `flutter test test/passkey_registration_prompt_test.dart --name "prompt behavior"` | ❌ Wave 0 |
| UI-04 | Error messages display correctly for passkey failures (unsupported, cancelled, failed) | widget | `flutter test test/passkey_error_messages_test.dart --name "error display"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test {modified_test_file} --reporter compact` (< 30s)
- **Per wave merge:** `flutter test packages/authenticator/amplify_authenticator/test --reporter compact` (full suite)
- **Phase gate:** Full suite green + manual verification before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/factor_selection_screen_test.dart` — covers UI-01 (factor selection screen rendering, passkey hiding)
- [ ] `test/passkey_signin_flow_test.dart` — covers UI-02 (full sign-in flow with passkey selection)
- [ ] `test/passkey_registration_prompt_test.dart` — covers UI-03 (post-auth registration prompt)
- [ ] `test/passkey_error_messages_test.dart` — covers UI-04 (error display and localization)
- [ ] Mock implementations: MockWebAuthnCredentialPlatform already exists from Phase 5
- [ ] Test utilities: amplify_authenticator_test package provides MockAuthenticatorApp, page objects

## Sources

### Primary (HIGH confidence)
- amplify-flutter codebase (auth_bloc.dart, auth_state.dart, form.dart, inherited_forms.dart, authenticator_screen.dart, auth_strings_resolver.dart) — verified existing architecture patterns
- amplify-ui React reference (SignInSelectAuthFactor.tsx, PasskeyPrompt.tsx, types.ts) — official UI patterns for passkey integration
- CONTEXT.md — user decisions and requirements from phase discussion

### Secondary (MEDIUM confidence)
- Existing test files (sign_in_test.dart) — established test patterns
- Phase 5 completion (MockWebAuthnCredentialPlatform) — test infrastructure available

### Tertiary (LOW confidence)
- None — all findings verified with codebase or official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components verified in codebase with line numbers
- Architecture: HIGH - patterns extracted from ContinueSignInWithMfaSelection, verified across 6+ files
- Pitfalls: HIGH - derived from common anti-patterns in existing code and user constraint violations
- Code examples: HIGH - all examples copied from existing codebase or adapted from verified patterns
- Validation: HIGH - test infrastructure confirmed, gaps identified for Wave 0

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (30 days — stable Flutter Authenticator architecture, unlikely to change)

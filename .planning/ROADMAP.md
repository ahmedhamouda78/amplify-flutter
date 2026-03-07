# Milestone v1.0: Passkey Support — Roadmap

## Phase 1: Foundation — Types, Serde, and Cognito API Clients

**Goal:** Establish all foundational types, serialization utilities, error types, and raw HTTP Cognito API clients needed by all downstream phases.

**Requirements:** FLOW-04, FLOW-05, AUTH-06, PLAT-07 (interface definition)

**Success Criteria:**
1. `AuthFactorType.webAuthn` is uncommented and functional in the type system
2. WebAuthn JSON types (PasskeyCreateOptions, PasskeyGetOptions, PasskeyCreateResult, PasskeyGetResult) are defined with base64url serde
3. Cognito API clients for `StartWebAuthnRegistration`, `CompleteWebAuthnRegistration`, `ListWebAuthnCredentials`, `DeleteWebAuthnCredential` are implemented via raw HTTP
4. `PasskeyException` hierarchy with typed error codes (notSupported, cancelled, assertionFailed, registrationFailed, rpMismatch) extends `AuthException`
5. `WebAuthnCredentialPlatform` abstract interface is defined with `createCredential`, `getCredential`, `isPasskeySupported` methods

---

## Phase 2: Sign-In Flow — State Machine WEB_AUTHN Integration

**Goal:** Enable passkey sign-in through the existing auth state machine by handling `WEB_AUTHN` challenge type and `SELECT_CHALLENGE` with WebAuthn selection.

**Requirements:** FLOW-01, FLOW-02, FLOW-03, AUTH-01

**Success Criteria:**
1. `signIn()` with `USER_AUTH` flow and `preferredFirstFactor: webAuthn` triggers `WEB_AUTHN` challenge handling
2. `CREDENTIAL_REQUEST_OPTIONS` is parsed from challenge parameters and passed to platform bridge
3. Platform bridge assertion result is serialized and sent via `RespondToAuthChallenge`
4. `SELECT_CHALLENGE` returns `continueSignInWithFirstFactorSelection` with `webAuthn` in available factors
5. `confirmSignIn(challengeResponse: 'WEB_AUTHN')` completes the two-step challenge flow

---

## Phase 3: Platform Bridges — iOS, Android, and Web

**Goal:** Implement native WebAuthn ceremony bridges for the three primary platforms so passkey sign-in and registration work end-to-end.

**Requirements:** PLAT-01, PLAT-02, PLAT-04, PLAT-08 (for these platforms)

**Success Criteria:**
1. iOS bridge wraps `ASAuthorizationPlatformPublicKeyCredentialProvider` for create/get operations (iOS 17.4+)
2. Android bridge wraps `androidx.credentials.CredentialManager` for create/get operations (API 28+)
3. Web bridge calls `navigator.credentials.create()` / `navigator.credentials.get()` via `dart:js_interop`
4. All three bridges accept JSON options and return JSON responses matching Cognito's expected format
5. Platform errors are mapped to typed `PasskeyException` subtypes

---

## Phase 4: Platform Bridges — macOS, Windows, and Linux

**Goal:** Extend passkey support to the remaining three platforms: macOS (shared Darwin), Windows (Windows Hello), and Linux (best-effort).

**Requirements:** PLAT-03, PLAT-05, PLAT-06, PLAT-08 (for these platforms)

**Success Criteria:**
1. macOS bridge shares iOS Darwin implementation via `ASAuthorizationController` (macOS 13.5+)
2. Windows bridge wraps Windows Hello FIDO2 API via FFI bindings
3. Linux bridge provides best-effort support via `libfido2` FFI or returns `isPasskeySupported() = false`
4. `isPasskeySupported()` correctly reports availability on all six platforms
5. Graceful error handling when passkeys are unavailable on a platform

---

## Phase 5: Credential Management — Register, List, Delete APIs

**Goal:** Expose high-level passkey credential management APIs that orchestrate Cognito calls and platform ceremonies.

**Requirements:** AUTH-02, AUTH-03, AUTH-04, AUTH-05

**Success Criteria:**
1. `associateWebAuthnCredential()` orchestrates: StartWebAuthnRegistration → platform ceremony → CompleteWebAuthnRegistration
2. `listWebAuthnCredentials()` returns paginated list of `AuthWebAuthnCredential` objects
3. `deleteWebAuthnCredential(credentialId)` removes a passkey from the user's account
4. `isPasskeySupported()` is exposed as a top-level auth category method
5. All APIs require authenticated user (access token) and throw appropriate errors if not signed in

---

## Phase 6: Authenticator UI — Passkey Screens and Flows

**Goal:** Integrate passkey support into the pre-built Authenticator widget with challenge selection, automatic ceremony triggering, and optional registration prompts.

**Requirements:** UI-01, UI-02, UI-03, UI-04

**Success Criteria:**
1. Challenge selection screen displays available auth methods including passkey icon/label
2. Selecting passkey triggers platform ceremony automatically and completes sign-in
3. Post-sign-in/sign-up passkey registration prompt is configurable (always/never)
4. Error messages for passkey failures are localized and include recovery suggestions
5. Existing non-passkey auth flows remain unaffected

---

## Requirement Traceability

| Requirement | Phase |
|-------------|-------|
| AUTH-01 | 2 |
| AUTH-02 | 5 |
| AUTH-03 | 5 |
| AUTH-04 | 5 |
| AUTH-05 | 5 |
| AUTH-06 | 1 | 1/5 | In Progress|  |
| FLOW-02 | 2 |
| FLOW-03 | 2 |
| FLOW-04 | 1 |
| FLOW-05 | 1 |
| PLAT-01 | 3 |
| PLAT-02 | 3 |
| PLAT-03 | 4 |
| PLAT-04 | 3 |
| PLAT-05 | 4 |
| PLAT-06 | 4 |
| PLAT-07 | 1 |
| PLAT-08 | 3, 4 |
| UI-01 | 6 |
| UI-02 | 6 |
| UI-03 | 6 |
| UI-04 | 6 |

**Coverage:** 23/23 requirements mapped (100%)

---
*Roadmap created: 2026-03-07*

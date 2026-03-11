---
status: complete
phase: 02-sign-in-flow
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md]
started: 2026-03-11T13:25:00Z
updated: 2026-03-11T13:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Direct WEB_AUTHN challenge completes passkey sign-in
expected: State machine auto-handles WEB_AUTHN challenge: extract CREDENTIAL_REQUEST_OPTIONS -> platform getCredential() -> RespondToAuthChallenge -> tokens returned
result: pass

### 2. SELECT_CHALLENGE includes webAuthn in available factors
expected: When Cognito returns SELECT_CHALLENGE with WEB_AUTHN in availableChallenges, state machine returns continueSignInWithFirstFactorSelection with AuthFactorType.webAuthn in available factors
result: pass

### 3. Two-step SELECT_CHALLENGE -> WEB_AUTHN completes sign-in
expected: User selects WEB_AUTHN via confirmSignIn('WEB_AUTHN'), Cognito returns WEB_AUTHN challenge, state machine auto-handles via platform bridge, sign-in completes with tokens
result: pass

### 4. Cancelled ceremony emits correct error
expected: When platform bridge throws PasskeyCancelledException during getCredential(), state machine emits SignInFailure with the exception (not a generic error)
result: pass

### 5. Missing platform bridge emits not-supported error
expected: When no WebAuthnCredentialPlatform is registered in dependency manager, state machine throws PasskeyNotSupportedException with recovery suggestion
result: pass

### 6. Missing CREDENTIAL_REQUEST_OPTIONS emits assertion error
expected: When WEB_AUTHN challenge parameters lack CREDENTIAL_REQUEST_OPTIONS key, state machine throws PasskeyAssertionFailedException
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0

## Gaps

[none]

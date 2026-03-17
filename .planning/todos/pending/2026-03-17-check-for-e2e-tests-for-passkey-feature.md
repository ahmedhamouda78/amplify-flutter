---
created: 2026-03-17T17:56:36.785Z
title: Check for e2e tests for passkey feature
area: testing
files:
  - packages/auth/amplify_auth_cognito
  - packages/authenticator/amplify_authenticator
---

## Problem

The v1.0 passkey feature shipped with 93 unit tests passing, but it's unclear whether end-to-end (e2e) integration tests exist for the passkey/WebAuthn flows. E2e tests would validate the full sign-in and registration flows against a real Cognito backend across platforms (iOS, Android, macOS, Windows, Linux, Web). Without them, regressions in the platform bridges or Cognito API integration could go undetected.

## Solution

1. Survey existing e2e test infrastructure in the repo (look for integration_test directories, device farm configs, or CI workflows that run on real devices/emulators)
2. Check if any existing e2e auth tests cover passkey flows
3. Assess feasibility of adding passkey e2e tests (requires Cognito user pool with WebAuthn enabled, platform availability constraints)
4. If feasible, plan e2e test coverage for: registration, sign-in, credential listing, error/fallback paths

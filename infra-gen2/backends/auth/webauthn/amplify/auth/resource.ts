// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import { defineAuth } from "@aws-amplify/backend";

export const auth = defineAuth({
  loginWith: {
    email: { otpLogin: true },
		phone: { otpLogin: true },
    webAuthn: true, // relyingPartyId auto-resolves to localhost in sandbox
  },
	passwordlessOptions: {
		preferredChallenge: "WEB_AUTHN"
	},
	userAttributes: {
		phoneNumber: {
			required: false
		}
	}
});

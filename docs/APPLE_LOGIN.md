# Sign in with Apple

The iOS and macOS login screen requests an Apple ID credential with a SHA-256
nonce. The app sends the returned credential to:

`POST /api/auth/apple/mobile/exchange`

The JSON request contains `authorizationCode`, `identityToken`, `rawNonce`,
`userIdentifier`, and—when Apple returns them on the first authorization—
`email`, `givenName`, and `familyName`.

The endpoint must validate the Apple identity token, its audience, issuer,
expiry, and nonce before returning the normal Jospar session in `accessToken`,
`access_token`, or `token`.

Before release, enable **Sign in with Apple** for the `com.josparbee.app` App ID
in the Apple Developer portal and regenerate the provisioning profile. The
Runner entitlement and Xcode capability are already included in the project.

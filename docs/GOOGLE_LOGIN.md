# Google login in the mobile application

The mobile flow uses the existing server Google client and HTTPS Google callback.
No Google client secret is placed in Flutter. No new Google Console redirect URI
is needed: the server finishes Google OAuth before redirecting to the app.

1. Flutter generates a random PKCE verifier, its S256 challenge and app state.
2. The system authentication browser opens `/api/auth/google?mobile=1` with
   `code_challenge` and `app_state`. The server signs these values in OAuth state.
3. After Google returns to `/api/auth/google/callback`, the server stores the
   session token with the challenge in Redis for 90 seconds. It returns only an
   opaque code and app state to `com.jospar.app://oauth/google`.
4. Flutter verifies the callback scheme, host, path and state, then sends the code
   and verifier to `POST /api/auth/google/mobile/exchange`.
5. The server checks PKCE and atomically consumes the code. Flutter stores the
   returned `access_token` in secure storage and opens the dashboard.

Cancellation leaves the login form available. A failed exchange does not create
a local authenticated session. Existing website and account-deletion flows retain
their original callbacks.

## Release dependency

Backend source changes are in
`/Users/erdaulettojbekov/Desktop/orbita/orbita-back/src/auth/`:
`google-auth.guard.ts`, `auth.controller.ts`, `auth.module.ts`,
`mobile-google.service.ts`, and `dto/mobile-google-exchange.dto.ts`.

Deploy the backend changes before releasing the mobile build. The backend uses
the existing BullMQ/Redis configuration; no database migration is required.
Ensure all API replicas use the same Redis. No production deployment is performed
by these local source changes.

Android registers the plugin CallbackActivity for `com.jospar.app://oauth/google`.
iOS receives this scheme through the plugin's ASWebAuthenticationSession.
Restart/rebuild the native app after adding the plugin; hot reload is insufficient.

## Device acceptance checks

- Google sign-in from a signed-out app opens the system browser, returns to the
  app and loads the authenticated dashboard.
- Closing the browser returns to the usable login form.
- Restarting the app retains the session; logout removes it.
- Existing email/password and website Google sign-in still work.
- Reusing a code, changing app state or using a wrong verifier fails.

Live Google sign-in on physical iOS/Android devices must be checked after backend
deployment. Unit tests do not establish that production OAuth is configured or
deployed.

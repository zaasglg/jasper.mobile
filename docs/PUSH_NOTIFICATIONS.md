# Mobile Firebase Cloud Messaging

Firebase project: josparbee-c8e89. Android applicationId: com.jospar.app.
The supplied android/app/google-services.json matches that applicationId.

## Implemented client

Uses the official native Android Firebase Messaging SDK and Google Services
Gradle plugin through the existing Flutter/native MethodChannel architecture.
iOS uses a native Swift bridge and Firebase Messaging 11.15.x to preserve the
existing iOS 14 deployment target. Its GoogleService-Info.plist matches the same
Firebase project and com.jospar.app bundle ID.

- Automatic Firebase initialization from Google Services generated resources.
- FCM token retrieval/rotation and deletion on logout; no tokens printed to logs.
- Notification channel jospar_messages and monochrome Android status icon.
- FirebaseMessagingService handles foreground/data messages and renders a native
  notification. Background notification messages use the Firebase SDK renderer.
- Notification taps from a cold/warm start are queued until authenticated routing
  is ready. taskId opens a task; threadId opens a conversation; optional
  chatMessageId focuses its source message. Unrecognized payloads open the
  notification feed. Payload URLs are never opened as arbitrary routes.
- Foreground reception also triggers the existing chat-list refresh signal.
- Settings → Notifications shows system permission/channel status, requests
  permission and opens Android notification settings. Debug builds provide an
  explicit copy-token button for Firebase Console's test-message workflow.

## Implemented server integration

Android and iOS register their tokens at authenticated POST /push/mobile/devices after
permission is granted. The server derives the account from the validated JWT and
binds the device to its active UserSession. DELETE on the same endpoint removes
this session's devices. Logout now revokes the server session before local logout;
foreign keys cascade device registrations and pending deliveries. Offline logout
also clears the native account binding and deletes the Firebase token.

The backend uses FCM HTTP v1 with Google OAuth credentials from
FIREBASE_SERVICE_ACCOUNT_FILE. The local credential is gitignored and never
bundled in the app. Browser Web Push uses its existing separate implementation.

New messages/mentions and targeted task activity enqueue persistent deliveries.
The worker retries transient failures, expires deliveries, removes unregistered
tokens and checks current session/access before delivery. Data-only payloads carry
recipientId; Android rejects payloads for a different or signed-out account.

## Release steps — not yet deployed

1. Review migration orbita-back/prisma/migrations/20261031160000_mobile_push/migration.sql.
   It adds device/queue tables and indexes, without changing existing data.
2. Provision the Firebase service account securely on the backend host, restrict
   access to the server process, and set FIREBASE_SERVICE_ACCOUNT_FILE to its path.
   The local developer path must not be copied into production configuration.
3. Apply the reviewed migrations through the normal release procedure
   (npm run db:deploy), generate the Prisma client, build and restart the backend.
   Check other pending migrations before using migrate deploy.
4. Install the new Android build, sign in, allow notifications, and check Settings
   → Notifications. Test a message between two controlled test accounts.

No production migration, deployment, or real-account message was performed in
this verification. Database-backed registration and event delivery were unit
tested; the complete production website-to-app path still needs a release check.

Incoming call pushes require a separately verified server payload and call
lifecycle integration. The existing CallKit/Android incoming-call UI is not proof
of delivery while the process is stopped. iOS app configuration, Push Notifications entitlement and remote-notification
background mode are now included. APNs key upload in Firebase and push-enabled
Apple provisioning still need release verification. PushKit delivery for incoming
calls remains separate.
Android force-stop from system settings prevents FCM delivery until app reopen.

## Validation

Dart tests cover permission/error handling, initial/live events, safe routing,
token rotation races, reset and unsupported platforms. Android builds validate
native Kotlin, Firebase Gradle setup and merged notification manifest components.
A test notification can be sent from Firebase Console to a copied device token;
this does not require a backend service-account file.

On 2026-10-31 the isolated Google Play API 36.1 ARM64 emulator received a real
FCM token. Using the configured server FcmClient and service account, a real test
notification was delivered while the app was in the background; Android's
notification service confirmed its package, channel and test title/body. No real
users were contacted. Token and key stay in gitignored .config files.
Evidence: [firebase-android-2026-10-31.json](verification/firebase-android-2026-10-31.json).

The final full Android build was installed and background delivery repeated. A
second data-only payload addressed to a different account was sent successfully
by FCM but was absent from Android notifications, confirming native suppression.
Android debug and signed iOS simulator builds passed; Flutter analyze passed;
372 Flutter tests passed and one visual fixture test was skipped.

## iOS integration

- GoogleService-Info.plist is explicitly included in Runner resources.
- Swizzling is disabled; AppDelegate forwards the APNs device token explicitly to
  Firebase Messaging. Token refresh events use the shared Dart bridge.
- The native bridge handles system permission, token deletion, settings,
  foreground messages, and cold/warm notification taps. Other notification
  delegates continue through FlutterAppDelegate.
- Registration sends platform=ios; the existing session-bound API accepts it.
- FCM transport uses APNs alert headers, sound, expiry and a generic lock-screen
  notification. Data-only Android delivery remains unchanged. iOS alerts can be
  displayed by the OS without launching the app; foreground/tap account checks
  cannot retract an alert already delivered during an offline logout race.
- The .p8 private key belongs in Firebase APNs configuration (and secure backup),
  never in the app bundle. Key upload is not verified by finding the client plist.
- These are ordinary notifications, not a PushKit/CallKit wake-up implementation.

On 2026-10-31 the iOS simulator build passed, the bundled Firebase project/bundle
IDs were verified, and the full app launched with the native Firebase bridge.
Flutter analyze and 13 affected client tests passed; backend typecheck and 27
push tests passed. This does not verify the Firebase APNs key upload, physical
APNs delivery, or production deployment. Evidence:
[firebase-ios-2026-10-31.json](verification/firebase-ios-2026-10-31.json).

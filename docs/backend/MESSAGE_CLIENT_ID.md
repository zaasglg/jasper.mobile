# Message retry deployment

Apply `message-client-id.patch` to the `orbita-back` repository. Add
`message-client-id-migration.sql` as a new Prisma migration, generate Prisma
Client, run typecheck and message tests, and deploy the migration and backend
before releasing the Flutter client. The checkout used for verification is
`.dart_tool/message-status-backend`; it is ignored by Git. No production changes
have been applied.

The optional UUID preserves compatibility with existing clients. Authenticated
authors and client IDs form a unique key. Duplicate and concurrent retries return
the existing message after checking conversation access, without emitting another
message-created notification. Body userId is deprecated and ignored.

Flutter persists outgoing text messages and quoted replies in secure storage,
partitioned by JWT subject and workspace. Interrupted sends become retryable after
restart. Retries retain the original UUID. Attachments and voice messages retain
their existing upload flow. Delivery and read checks use the existing foreground
10-second conversation refresh. Russian and Kazakh labels are defined alongside
the compact status indicator.

# Mobile call protocols

The mobile client uses the web call-summary contract. A protocol is a structured
record of entries, participants and decisions; the summary endpoint does not run
an AI transcription job.

## User flow

- During a connected call, open the document icon in the header. Add notes and
  mark key decisions. Notes are sent to other call participants through LiveKit.
- After hangup, select **Подготовить протокол**, review notes, then save. Saving
  is explicit and requires the server's `canGenerate` permission.
- A super administrator can grant participants permission during an active call.
- Open the document icon on an ended call message to view saved versions later.
  For the current in-memory call this also reopens the draft. Starting another
  call or signing out clears the unsaved draft; saved versions remain on server.

## Verified web contract

Inspected on 2026-11-26: public dashboard layout's lazy `VideoMeeting` chunk
`5300.bc16b0854c630164.js`, client module 99174, and local backend video controller,
service, DTOs and `summary-content.ts`.

All requests carry the room workspace ID:

- `GET video/rooms/:id/summary-access`: `canGenerate`, `canManage`, participants,
  `grantedUserIds`. Access is refreshed every five seconds during the call.
- `PUT video/rooms/:id/summary-access`: `{userId, enabled}`.
- `POST video/rooms/:id/summary/generate`: authorization only.
- `POST video/rooms/:id/summaries`: `{documentNumber, duration, participantCount,
  content}`. `content` follows the web document format: `allEntries`,
  `keyDecisions`, `participantIds`, `participantDetails`, timestamps and counts.
- `GET video/rooms/:id/summaries?skip=0&take=20`: paginated version metadata.
- `GET video/rooms/:id/summaries/:summaryId`: persisted content.

The server filters previously saved entry fingerprints and rejects a new version
without new entries. A failed save retains the draft. Room and generation checks
ignore responses from a previous call/account reset.

LiveKit receives web `speech`, `chat`, `key-decision`, and
`summary-access-changed` packets. Web chat packets have no entry ID, so mobile
assigns one. Speaker identity is taken from LiveKit's authenticated participant,
not the packet's userId. Malformed or oversized packets and duplicate speech IDs
are ignored. Duration and local identity are frozen before media disconnects.

## Limits and verification

- This implementation does **not** transcribe the phone's own microphone. The
  web uses browser SpeechRecognition. Starting the existing mobile
  speech_to_text recorder alongside LiveKit has not been validated and is not
  enabled. Received web speech and explicit mobile notes are supported.
- File transfer, export and creating tasks from individual protocol entries are
  not included in this mobile protocol surface.
- Notes are not automatically persisted before the user saves the protocol.
- Unit/widget tests cover API paths/envelopes/access errors, web packets,
  decisions, draft retention, account-reset races, and the compact dark layout
  with enlarged text. Run `flutter test test/features/calls` and `flutter analyze`.
- A real mobile-to-web call and device microphone coexistence were not tested.

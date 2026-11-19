# Google Calendar in the mobile daily planner

The app reuses the website's existing backend integration; no web or server files
were changed. Connection belongs to the signed-in Jospar user (not a workspace).
The OAuth token stays on the backend and is shared with Google Drive.

## Flow

Daily planner → Sources of calendar (top right) → Connect Google Calendar.
The authenticated app obtains `GET google-drive/auth` and opens the returned
Google HTTPS authorization URL in the system browser. Google returns to the
existing server callback and web completion page. Return to Jospar to refresh
status; a bounded two-minute status check also runs after authorization starts.
No mobile Google client secret or bearer-token URL is introduced.

Already connected website accounts work without reconnecting. Read-only grants
are identified and the UI offers reauthorization for write access. Disconnect
requires confirmation and explicitly mentions that Drive is also disconnected.

## API

- GET `google-drive/calendar/status`: connected, canWrite.
- GET `google-drive/calendar/events`: UTC timeMin/timeMax, take 50,
  includeHolidays, opaque pageToken. Every page is loaded, repeated cursors fail,
  duplicate event IDs are removed.
- DELETE `google-drive/disconnect`: revoke the shared Google connection.

Events appear in day/week/month views. Multi-day timed events are split at GMT+5
midnight. All-day dates preserve their calendar date and Google's exclusive end.
External events show read-only details; completion and drag rescheduling are
disabled. Google loading failures do not prevent using Jospar's own planner.
Source switches can hide Google events or holiday calendars in this screen.

The daily planner belongs to the signed-in account. Mobile loads all pages of
`GET project-planner/account` (`skip`/`take`, 250 per page), creates personal
entries with `POST project-planner/account/tasks`, and adds Inbox tasks through
`POST project-planner/account/inbox-tasks`. No selected workspace is required.
Updates and removal continue through `project-planner/items/:id`. Linking an
existing project task still uses `POST project-planner/:projectId/tasks`, as
required by the backend; it appears in the account-wide list. Tasks are fetched
only when the user explicitly opens the existing-task picker. Due dates are not
automatically imported into the planner.

Linked completion uses `PATCH project-planner/items/:id/completion` so that an
older server cannot forward the checkmark to the source task. This requires the
server patch described in [PLANNER_LIFECYCLE.md](backend/PLANNER_LIFECYCLE.md).
Planner completion and archive come from the planner entry itself.

Backend contract checked against `zaasglg/orbita-back` commit
`c08a34bbdd00eb9f63792eb460db5c27ac1e3207` (controller, service, account tests).
This checks source compatibility; authenticated production behavior still needs
verification on a device.

 The existing backend GooglePlannerSyncService exports eligible scheduled
entries to the user's primary Google calendar approximately every minute. It
updates/deletes only its own exported events; imported Google events are not
written by the app. The backend excludes exported entries from imports to avoid
duplicates. This depends on the deployed backend's worker and configured OAuth.

## Validation

`flutter analyze`
`flutter test test/features/planner test/widget_test.dart`

Tests cover API shape and pagination, repeated cursors, GMT+5 all-day/exclusive
end and midnight boundaries, website connection reuse, disconnect, error state,
stale month responses, and rendering read-only events/settings in the planner.
These tests use fake HTTP/accounts. Granting real Google consent and verifying
a real exported event require the user's Google authorization and a deployed
worker; those are not claimed as tested by unit/widget tests.

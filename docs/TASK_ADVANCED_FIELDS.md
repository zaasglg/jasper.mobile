# Mobile task details: location, dependencies, start and discussions

The app uses the existing web/backend formats. No website or backend files were
changed for this implementation.

- `PATCH project-tasks/:id` with `start` (UTC ISO or explicit null) edits/clears
  start date. The picker rejects a start after the task's end date.
- The same endpoint with `deps: string[]` edits predecessor display IDs, matching
  the website. Related tasks are loaded through ProjectTaskRepository. The UI
  renders incoming/outgoing links, supports opening related task cards and
  rejects dependency cycles detectable in the project graph. Unknown existing
  dependency IDs are retained unless explicitly removed.
- Location is `detail.location: {address, latitude?, longitude?}`. Editing and
  clearing preserve the rest of detail, including fields unknown to the app.
  The editor uses Yandex Maps 2.1 with the existing YANDEX_MAPS_API_KEY build
  define: map click/reverse geocoding, address search, marker selection. Manual
  address/coordinates remain available when the map cannot load. Existing
  DashboardTaskMap renders the saved point. External links use longitude,
  latitude ordering as Yandex expects.
- Description editor uses a local contenteditable WebView. It supports headings,
  bold, italic, underline, strike, lists, quotes/code blocks, alignment, links,
  separators and undo/redo. A Dart allow-list removes executable markup before
  content enters the editor and before saving. User content is base64 encoded
  in bootstrap HTML. Native preview renders formatting without visible tags.
  Unsupported platforms use plain text editing, preserving untouched HTML.
  Saving awaits the backend; failed requests leave the editor/draft open.
- Discussion attachments use the atomic `POST project-tasks/:id/comments` API,
  with `{text, files: [{name,dataUrl,size:string,type}]}`. Author, timestamp and
  ID come from the server. File-only comments work. The existing picker enforces
  10 MB/file; the composer enforces 10 files/comment. Draft text/files clear only
  after a successful response. Existing web comment files are parsed and open
  through the shared storage preview. Comments do not replace the entire detail
  JSON, avoiding concurrent comment overwrites.

## Verification

Tests include API DTOs/null clearing, model round trips, field preservation,
location validation, coordinate order, dependency cycle detection, safe HTML,
failed comment attachment retry and failed description retry. Existing task
screen tests also cover narrow layouts, existing file upload and HTML editing.

A local browser check loaded the generated description document, selected text,
clicked formatting controls and checked the saved HTML bridge payload. No real
user messages or production task mutations were made during these tests.
Yandex availability/geocoding depends on the existing configured key and network.

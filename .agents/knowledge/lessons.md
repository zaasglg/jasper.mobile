# Jospar Agent Lessons

This file stores verified, reusable lessons learned while working in this repository. All project agents read it before making relevant decisions.

See `docs/AI_AGENTS.md` for acceptance criteria and the required entry format.

## Shared

No verified lessons recorded yet.

## Feature and architecture

### Normalize call events before formatting activity text

- Date: 2026-11-24
- Scope: feature
- Evidence: call JSON shown in the notifications screenshot; `activity_repository_test.dart` covers direct/nested events, legacy calls, typed malformed payloads and quoted metadata; `notifications_screen_test.dart` verifies readable call text in both themes.
- Lesson: Activity feeds can return messenger call payloads in `text`, including legacy entries without `kind`. Recognize `CALL` or a nonempty string `callId`, parse the original transport text through the messenger model before HTML conversion, and display its call heading. A generic user JSON object with `mode` alone must remain user content.
- Apply when: mapping notifications, mentions, reactions or saved-message previews from activity endpoints.

### Preserve planner links across dates and legacy workspace fields

- Date: 2026-11-24
- Scope: feature
- Evidence: backend `ProjectPlannerItem.taskId @unique` and `ProjectPlannerService.addTask` update existing links; `ai-day-plan.service.spec.ts`; `ai_day_plan_test.dart`.
- Lesson: A project task has one planner link across dates, and adding it with a schedule can modify that link. Exclude existing task links before AI planning and recheck before confirmation, regardless of their date or archive state. In backend queries scope links through `task.workspaceId`, because legacy project planner entries may have a null `workspaceId`.
- Apply when: recommending tasks for the planner, retrying linked task additions, or filtering legacy planner records by workspace.

### Route widget capture actions to a focused composer

- Date: 2026-11-24
- Scope: feature
- Evidence: user correction; `inbox_quick_add_screen_test.dart`; `InboxHomeWidget` simulator build.
- Lesson: The Inbox home-widget add action must open the dedicated `/inbox/quick-add` composer with immediate keyboard focus, not the full Inbox shell. Keep the general widget tap routed to `/inbox` and the add affordance routed to `action=add`.
- Apply when: changing home-widget links, cold-launch routing, or Inbox capture UX.

### Match the web project move contract

- Date: 2026-11-23
- Scope: feature
- Evidence: public web client `layout-659fc94fc63a809d.js` and `1930-1947de494bbd38fd.js`; `test/features/projects/project_move_test.dart`.
- Lesson: Project hierarchy/order moves use `PATCH projects/{id}/move` with `workspaceId`, `group: tree`, explicit nullable `parentId`, `placement: append|before|after`, and `anchorId` for sibling placement. The web permits one child level; a project with children cannot become a child. Infer parent IDs from nested responses before validating moves.
- Apply when: changing project drag/drop, hierarchy, or move API integration.

### Publish projects with their calculated progress atomically

- Date: 2026-11-23
- Scope: feature
- Evidence: delayed-load, refresh and progress-failure tests in `projects_cubit_test.dart`.
- Lesson: `projects.progress` can differ from progress calculated from tasks. When the task repository is configured, publish projects and task summaries in one state after both requests finish. During refresh retain the previous complete snapshot; on progress failure retain verified values or show retry on initial load. Do not briefly display the raw project percentage as a fallback.
- Apply when: changing project loading, refresh, or progress rendering.

### Planner symbols use a separate positional API

- Date: 2026-11-23
- Scope: feature
- Evidence: public web modules 62077 and 85315 in `3683.b99c077987c0b4ef.js`; `planner_task_icons_test.dart`.
- Lesson: Fetch symbols through `POST ai/assistant/task-icons` with `{titles: [...]}` in batches of 30 and titles capped at 500 characters. The response `{icons: [...]}` matches request order; it is not a title-keyed map or image URL. A planner item's explicit `icon` takes precedence. Load classification independently of planner entries and keep completion callbacks unchanged.
- Apply when: integrating or changing planner task symbols.

### Omit absent planner checklist dates from write payloads

- Date: 2026-11-23
- Scope: feature
- Evidence: backend `PlannerCheckItemDto` uses `ValidateIf(value !== undefined)` plus `IsString` for `dueDate`; regression coverage in `planner_entry_extras_test.dart` rejects explicit null dates, including section items.
- Lesson: Build planner checklist write payloads explicitly. The shared task model emits `dueDate: null` for undated items, but the planner API accepts only an omitted field or a string. Apply the same mapping to section items.
- Apply when: changing planner checklist serialization or reusing task models for planner writes.

### Keep channel photo permissions and cache separate from membership management

- Date: 2026-11-23
- Scope: feature
- Evidence: `channel_images_test.dart` covers independent `canManageImage`/`canManage`, parent/child images, failed writes, and a list response delayed across a successful photo save.
- Lesson: Photo actions require strict `canManageImage == true` from channel members metadata, regardless of `canManage`. Send JSON `imageUrl` (explicit null removes it), publish successful changes by channel ID to mounted avatars/list state, and prevent a GET started before a save from reverting the shared image snapshot. Version image-cache keys on successful writes, including when the URL is unchanged.
- Apply when: changing channel/subchannel photos, information panels, or messenger cache synchronization.

### Match message thread heads by ID before participant fallbacks

- Date: 2026-11-24
- Scope: feature
- Evidence: backend `thread-list-query.ts`; mobile `chat_previews_test.dart` covers a channel whose last author is also a DM recipient, independent subchannel heads, and clearing absent heads.
- Lesson: `GET messages/threads` already contains the latest `text` and author `user` for each canonical `threadId`. Match channel IDs and sorted `dm:` IDs first. The `user` in a head is its last author, not a recipient, so never use it as a DM participant fallback. Reuse these heads for previews rather than fetching each chat history.
- Apply when: mapping thread summaries, unread counts, or last-message previews.

### Copy columns with one server operation and reconcile uncertain writes

- Date: 2026-11-24
- Scope: feature
- Evidence: `test/features/kanban/column_copy_test.dart` verifies exact request body, populated/empty columns, filtered boards, timeout reconciliation, late replies and the menu-to-scroll flow.
- Lesson: Column copies use `POST kanban-columns/{id}/copy` with only trimmed `name` and `afterColumnId: id`. Omit `taskIds` so local filters never limit server copies. After success reload the board; after a timeout reconcile with GET and require explicit inspection rather than retrying POST. Scope both the write result and its follow-up load to the active account, project and sheet. Wait for the sheet route transition to complete before scrolling the underlying board.
- Apply when: changing column copying, write reconciliation or navigation following board mutations.

### Match the web resource summary to visible tasks and named adjacent pairs

- Date: 2026-11-24
- Scope: feature
- Evidence: local `orbita-front/components/tasks/TaskResourceSummary.tsx` and `KanbanView.tsx`; `test/features/kanban/column_resource_test.dart` covers exact-name pairs, inline data, bounded fallback GETs, pagination, failures and compact light/dark sheets.
- Lesson: A column resource summary receives the visible column tasks, including active filters and the completed-card setting. Sort resources by order per task, pair adjacent rows, use the top row's planValue and bottom row's factValue, and aggregate only by both trimmed names. Preserve omitted resources as null versus authoritative empty arrays in task DTOs. Reuse complete inline resources and fall back to `GET tasks/{id}/resources` only when needed; publish totals only after every task succeeds.
- Apply when: changing resource summaries, task resource snapshots or filtered column analytics.

## UI and accessibility

### Keep the resize grip inside the timed task drag source

- Date: 2026-11-24
- Scope: UI
- Evidence: `planner_without_time_test.dart` timed-slot transfer initially hit the sibling resize region; timed transfer, centered-grip resizing, cancellation and unchanged-time tests pass with a shared drag source.
- Lesson: A centered 44-pixel resize hit region can overlap a compact planner title. Keep the grip and task body inside one `LongPressDraggable` so holding selects transfer while immediate vertical movement selects resize. Keep that wrapper mounted during resize and disable new drags with `maxSimultaneousDrags: 0`; preserve the grab offset and ignore horizontal-only movement when computing a new start time.
- Apply when: changing timed planner transfers, resize affordances, or gesture arbitration on compact cards.

### Cancel planner resize before a drag end can save

- Date: 2026-11-24
- Scope: UI
- Evidence: `planner_without_time_test.dart` cancellation regression initially saved on `TestGesture.cancel`, then passed with a raw pointer-cancel listener; pending-save and edge-scroll tests in `planner_day_agenda_test.dart`.
- Lesson: An accepted vertical resize drag can report an end when its pointer is cancelled. In planner resize handles, clear the gesture through `Listener.onPointerCancel` before the end callback can save. Keep the adaptive scale fixed during tracking and retain the preview until the save finishes.
- Apply when: changing planner duration gestures, their cancellation handling, or adaptive-scale previews.

### Never render unnamed epics as blank selection rows

- Date: 2026-11-24
- Scope: UI
- Evidence: user screenshot; `task_extras_test.dart` covers empty epic names and compact row height.
- Lesson: Epic selectors must render a visible `Без названия` fallback for blank server names. Use compact rows with the epic color and an explicit selected state so a malformed name cannot leave an unexplained standalone checkbox.
- Apply when: rendering epic catalogs, filters, or task epic editors.

### Keep project drag identity through live reparenting

- Date: 2026-11-23
- Scope: UI
- Evidence: live list/grid reparenting tests in `projects_screen_test.dart` and `project_move_test.dart`.
- Lesson: Live project drag previews rebuild from an immutable pre-drag snapshot. Keep each `ProjectDrag` globally keyed by project ID across root/child and grid-column changes, and supply the sliver item-index callback. Otherwise reflow can dispose the active draggable before its end callback. Preview changes stay local; commit once on release and restore on cancellation or request failure.
- Apply when: changing live project reordering or reparenting layouts.

### Match the web adaptive day scale, not a fixed hourly grid

- Date: 2026-11-23
- Scope: UI
- Evidence: web `lib/planner-day-scale.ts`, `PlannerDayBackground.tsx`, `PlannerTaskSymbol.styles.ts`; mobile `planner_day_scale_test.dart` and `planner_day_agenda_test.dart`.
- Lesson: The web day view maps time with a piecewise scale: expand occupied intervals for readable task heights, compress free intervals, and distribute remaining viewport space across gaps. Labels are 6:00, 9:00, 12:00, 15:00, 18:00; task symbol capsules sit on the vertical rail with plain titles alongside. Preserve the adaptive scale when adding time labels to the mobile day view.
- Apply when: changing daily planner layout, hour markers, task positioning, or day-view parity with web.

### Preserve the active input theme inside editing sheets

- Date: 2026-11-24
- Scope: UI
- Evidence: `test/core/theme/theme_test.dart`, dark editing-sheet regression test; `AppFormSurface`.
- Lesson: `AppFormSurface` must retain the active `ThemeData.inputDecorationTheme`. Applying `AppInputTheme.light` inside this wrapper restores light input fills even when the application is dark. Resolve shared palette roles through `AppColors.of(context)` in widget builds.
- Apply when: changing shared form wrappers, theme overrides, or application appearance.

## Testing and verification

No verified lessons recorded yet.

## Review and quality

No verified lessons recorded yet.

## Idea council and product decisions

No verified lessons recorded yet.

### Keep queued messages compatible with message validation

- Date: 2026-11-24
- Scope: feature
- Evidence: `chat_outbox_test.dart` legacy validation regression; existing message DTO patch in `docs/backend/message-client-id.patch`.
- Lesson: Queued text sends must include the authenticated `users/me` userId for older servers. Remove clientId and retry only after HTTP 400 explicitly reports `property clientId should not exist`; retain the UUID on other failures. Server deduplication requires the backend migration.
- Apply when: changing message outbox payloads or rolling out clientId support.

### Keep AI widget launches separate from Siri voice launches

- Date: 2026-11-24
- Scope: feature
- Evidence: `assistant_launch_test.dart` cold/repeated keyboard and voice cases; `assistant_test.dart` keyboard focus without microphone activation.
- Lesson: Route `jospar://assistant?homeWidget&keyboard=true` through `AssistantLaunchService.requestLaunch(voice: false)`. Preserve it through splash/login and focus the existing assistant on repeat instead of stacking routes. Siri retains the voice launch path. The iOS widget extension uses a WidgetBundle to expose both Inbox and AI widgets.
- Apply when: adding assistant home-screen actions or changing widget/Siri routing.

### Gate workspace tabs before building their content

- Date: 2026-11-24
- Scope: feature
- Evidence: `workspace_access_gate_test.dart`; new-account integration test in `workspace_sync_screen_test.dart` verifies zero tab builds/project requests with an empty workspace list, stale-selection clearing, and recovery after creation.
- Lesson: `MainShell` must wait for `WorkspaceLoaded.selected` before mounting workspace-dependent tabs or their navigation. Use `WorkspaceAccessGate` for loading, retry, and first-workspace creation; do not equate request failure with an empty account. Reuse `WorkspaceCubit.createWorkspace` so selection and storage follow the existing flow.
- Apply when: changing authenticated startup, tab initialization, or the first-workspace experience.

### Keep assistant history scoped and historical actions read-only

- Date: 2026-11-24
- Scope: feature
- Evidence: `assistant_history_test.dart` covers account/workspace isolation, restart, deletion, transport cancellation, stale replies and cancelled-context exclusion; `assistant_test.dart` covers historical draft safety and conversation draft switching.
- Lesson: Persist assistant snapshots under an immutable account/workspace scope and strip upload bytes while retaining file metadata and action states. Restore historical drafts read-only to prevent duplicate creates or stale edits. Stop must cancel both extraction/chat requests, invalidate late results, and exclude the interrupted user turn from subsequent model context; server-side actions already executed are not rolled back.
- Apply when: changing assistant persistence, cancellation, or restored action cards.

### Translate explicit UI templates without rewriting user content

- Date: 2026-11-24
- Scope: feature
- Evidence: `test/core/localization/locale_test.dart` verifies exact web lookup, explicit parameters, unchanged user titles and stale locale saves across account changes; `profile_repository_test.dart` verifies locale-only PATCH and server confirmation.
- Lesson: Web translations use normalized Russian source text with FNV-1a keys. Resolve only exact static labels or explicit parameter templates; pattern matching interpolated strings can accidentally translate user-authored project/task names. Keep mobile additions separate and require explicit server locale confirmation before publishing a saved profile language. Invalidate pending saves on account changes.
- Apply when: adding mobile translations, refreshing the web dictionaries, or changing profile-language synchronization.

### Match the web dashboard scope and completion rule

- Date: 2026-11-24
- Scope: feature
- Evidence: web modules 65038/18787 use progress >= 100; dashboard `ER.timing` uses paginated `project-tasks/timing`; KPI project count uses root projects. `dashboard_data_parity_test.dart` covers root counts and filtering after pagination.
- Lesson: Completion follows progress >= 100, independently of DONE column placement. Dashboard data must use the timing feed, which excludes archived/deleted columns server-side. Count root projects for the unfiltered KPI while including child tasks. Do not infer parity merely from task-list tests. Planner completion remains independent.
- Apply when: changing task completion, dashboard totals, or comparing mobile and web statistics.

### Keep preferences on the verified iOS platform-channel release

- Date: 2026-11-24
- Scope: feature
- Evidence: device log `PlatformException(unregistered-instance, LegacyUserDefaultsApi has not been registered)` from shared_preferences_foundation 2.6.2; package changelog identifies the FFI migration in 2.6.0; resolved Swift package uses 2.5.6 after the override.
- Lesson: Keep shared_preferences_foundation pinned to 2.5.6 for this app until its FFI registration has been verified with the app's native engines. A native plugin version change requires a full stop and rebuild, not hot reload/restart. Preserve stored preferences when diagnosing this issue.
- Apply when: updating Flutter foundation plugins or diagnosing preferences writes failing on iOS.

### Filter iOS background alerts on the server

- Date: 2026-11-24
- Scope: feature
- Evidence: `fcm-client.ts` sends visible APNs alerts; `notification_preferences_test.dart` verifies per-account state and midnight boundaries; backend preferences tests cover DST, session ownership and suppressed deliveries.
- Lesson: Device notification preferences need server filtering before FCM for background iOS alerts; foreground delegate filtering alone cannot suppress an OS-rendered APNs banner. Keep per-device preferences session-bound, send the native IANA timezone, consume suppressed queue entries, and report failed server synchronization explicitly. Quiet hours must not change in-app content or call handling.
- Apply when: adding notification categories, quiet hours, or background push policies.

### Use the existing personal planner hasTime contract

- Date: 2026-11-24
- Scope: feature
- Evidence: local backend `CreatePlannerTaskDto` / `UpdatePlannerItemDto`; `planner_without_time_test.dart` personal create/update/reload coverage.
- Lesson: Personal untimed entries use `/account/tasks` and ordinary item PATCH with `hasTime: false` and local midnight converted to UTC in `scheduledAt`. Keep the mobile date-only representation after parsing. Do not infer the same create contract for linked entries: `AddPlannerTaskDto` lacks `hasTime`.
- Apply when: changing personal planner creation, scheduling or timestamp serialization.

### Load dashboard quotations from the web daily motivation contract

- Date: 2026-11-26
- Scope: feature
- Evidence: public web module 99174 (`9174-f1cad5768b57300a.js`) and dashboard `em`; `test/features/dashboard/daily_quote_test.dart` verifies workspace scoping, payload parsing and delayed old-workspace replies.
- Lesson: The dashboard header quotation uses `GET ai/daily-motivation?workspaceId=...` with `quote.text`, `quote.author` and optional `refreshing`. It is separate from the AI recommendations widget. Match the web polling interval of 1500 ms while refreshing and five minutes otherwise; scope UI state to account/workspace and pause polling in the background.
- Apply when: changing dashboard greeting quotations or daily motivation loading.

### Keep the LiquidGlass shader subtree immutable

- Date: 2026-11-26
- Scope: UI
- Evidence: device `RenderBackdropFilter ... hasSize` failure; upstream liquid_glass_fx 0.0.2 LayoutBuilder captures `content` recursively; `test/core/widgets/liquid_glass_layout_test.dart` covers the extracted shader layout at two widths.
- Lesson: Use the patched local package in `third_party/liquid_glass_fx`. Its shader layout holds the blur subtree as an immutable child and loads the shader with the package-qualified asset key. Skia widget tests exercise only the blur fallback unless the shader layout is tested separately.
- Apply when: upgrading liquid_glass_fx or changing bottom-navigation shader rendering.

### Lift nested floating actions above the shell navigation

- Date: 2026-11-26
- Scope: UI
- Evidence: planner/messenger action hidden behind glass navigation in user screenshot; `app_floating_action_button_location_test.dart` checks visibility and taps with zero and 34-pixel safe insets.
- Lesson: With MainShell.extendBody enabled, nested Scaffold floating actions can sit behind the shell bar. Use AppFloatingActionButtonLocation, subtracting the added bottom padding beyond the physical viewPadding from the default endFloat offset. Keep the native bottom safe inset counted once.
- Apply when: adding floating actions to screens hosted below the shell's overlaid navigation.

### Accept week drag tokens before onDragStarted fires

- Date: 2026-11-26
- Scope: UI
- Evidence: initial same-day widget drags showed an insertion line but did not commit; `planner_week_drag_test.dart` and the iOS integration suite pass with token-only acceptance and active-drag validation on drop.
- Lesson: Flutter can hit-test the enclosing day DragTarget before invoking LongPressDraggable.onDragStarted. Validate scope/day with an instance token in onWillAccept, and check the active source again on drop. Requiring a nonnull active source during first entry rejects the entire day until the pointer leaves and re-enters it. Keep the original Wrap stable while showing an insertion marker.
- Apply when: changing manual ordering or drop regions in PlannerWeekView.

### Call summary generation authorizes a client-built document

- Date: 2026-11-26
- Scope: feature
- Evidence: web VideoMeeting/client module 99174, backend video controller/service and `summary-content.ts`; `test/features/calls/call_protocol_test.dart` checks request ordering and payload.
- Lesson: `POST video/rooms/:id/summary/generate` only authorizes; it does not transcribe or generate content. Save web-compatible `allEntries`, participant metadata and decisions through `POST .../summaries`. The server keeps incremental new entry fingerprints. Browser speech arrives through LiveKit `speech` packets; web `chat` packets have no ID. Do not enable a second mobile microphone recorder without verifying coexistence with LiveKit.
- Apply when: implementing call protocols, transcription, summary versions or web/mobile call interoperability.

### Match web planner completion by task source

- Date: 2026-11-26
- Scope: feature
- Evidence: current public web PlannerDrawer chunk `606` (`completeMutation` and Inbox mapping); `planner_repository_test.dart` covers project/Inbox reload, undo, rejected writes and consumer invalidation.
- Lesson: Per the user's web-parity decision, linked project completion calls `PATCH project-tasks/:taskId` with progress 100/0. Inbox and standalone completion use `PATCH project-planner/items/:plannerItemId` with completed. Read project completion from task.progress, Inbox completion from inboxTask.detail.completed, and standalone completion from the planner completed field. The proposed independent `/completion` endpoint is no longer used and its backend patch is historical. Notify cached task consumers after a successful project change, without making the planner reload itself mid-save.
- Apply when: changing planner completion, source identity, serialization or cross-screen status refresh.

### Keep the primary workspace separate from aggregate selection

- Date: 2026-11-27
- Scope: feature
- Evidence: public web dashboard workspace selector; `workspace_cubit_test.dart`, `workspace_multi_select_test.dart`, `projects_cubit_test.dart`, and `scoped_dashboard_repository_test.dart`.
- Lesson: Multiple workspace selection retains a primary workspace for configuration and write context while aggregating projects and dashboard reads across the selected IDs. Refresh the aggregate when IDs change even if the primary stays unchanged. Filter each project response by its requested workspace because an account-wide response can otherwise duplicate projects; keep the primary inside the surviving selection after access changes.
- Apply when: changing workspace selection, shared dashboard caches, project aggregation, or workspace-scoped writes.

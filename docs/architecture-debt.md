# Архитектурный долг

Эти зависимости presentation → data оставлены без изменения в шагах разделения сущностей и DTO. Каждую следует устранить отдельной задачей, сохранив тип исключения и поведение обработки ошибок.

| Исключение | Текущий путь зависимости | Предлагаемая отдельная задача |
|---|---|---|
| `AuthException` | `lib/features/auth/presentation/cubit/auth_cubit.dart` → `lib/features/auth/data/repositories/auth_repository_impl.dart` | Перенести исключение в `lib/features/auth/domain/exceptions/auth_exception.dart`; обновить импорты реализации, Cubit и тестов. |
| `ProfileException` | `lib/features/profile/presentation/cubit/profile_cubit.dart` → `lib/features/profile/data/repositories/profile_repository_impl.dart` | Перенести исключение в `lib/features/profile/domain/exceptions/profile_exception.dart`; обновить импорты реализации, Cubit и тестов. |
| `WorkspaceException` | `lib/features/workspaces/presentation/cubit/workspace_cubit.dart` → `lib/features/workspaces/data/repositories/workspace_repository_impl.dart` | Перенести исключение в `lib/features/workspaces/domain/exceptions/workspace_exception.dart`; обновить импорты реализации, Cubit и тестов. |

## Участники проектов: presentation → data

`lib/features/collaboration/presentation/project_participants_cubit.dart` и `project_participants_screen.dart` используют конкретный `ProjectParticipantsRepository`, а также `ProjectInvitation` / `ProjectAccessLink` из `lib/features/collaboration/data/project_participants_repository.dart`. Отдельной задачей выделить domain-интерфейс репозитория и чистые сущности, оставив Dio и сериализацию в data. `CollaborationException` уже находится в domain и переноса не требует.

## Формат активности участника

SpaceMember.lastActiveAt — формат не установлен (ISO или готовый текст). Уточнить у API участников; если ISO — парсить в DateTime в SpaceMemberDto, форматирование — в presentation; если готовая строка — оставить String?.

## Звонки: зависимости presentation → data

- `lib/features/calls/presentation/call_screen.dart` → `lib/features/calls/data/livekit_call_media.dart` (`LiveKitCallMedia`). Отдельной задачей расширить domain-интерфейс медиасессии нужными представлению возможностями и скрыть LiveKit за адаптером data; SDK-объекты оставить в data.
- `lib/features/calls/presentation/system_call_controller.dart` и `calls_host.dart` → `lib/features/calls/data/system_incoming_calls.dart` (`SystemIncomingCalls`). Отдельной задачей ввести domain-интерфейс системных звонков, платформенную реализацию оставить в data и подключить через DI.
- `lib/features/calls/presentation/calls_host.dart` → `lib/features/calls/data/call_events.dart`. Отдельной задачей выделить domain-контракт потока событий звонков, платформенные источники и декодирование оставить в data.
- `lib/features/calls/presentation/call_cubit.dart` → `lib/features/calls/data/call_message_changes.dart`. Отдельной задачей выделить domain-интерфейс уведомления об изменениях звонка, конкретный канал обновления сообщений оставить в data и внедрять через DI.

`CallException` уже находится в domain и переноса не требует.

## Помощник: динамические данные и зависимости

- AssistantDraft.patch — динамическая карта, UI перебирает ключи; типизировать после уточнения структуры patch отдельной задачей.
- `AssistantToolResult.updated`, `action`, `attachment` остаются nullable `Map<String, dynamic>`, а `results` — nullable `List<dynamic>`: результаты инструментов имеют разные формы, включая вложенные attachment. Уточнить отдельные контракты инструментов и типизировать отдельно; неизвестные верхнеуровневые поля tool/result/draft сохраняются только в DTO. `error` сохраняется как `Object?`; `hasError` отличает отсутствующий ключ от явного null, чтобы не выполнять ошибочный tool-result.
- `assistant/presentation/cubit/assistant_cubit.dart` и `presentation/widgets/assistant_action_cards.dart` используют `data/services/assistant_actions.dart` (`AssistantActions`), а также `data/services/assistant_task_changes.dart`; screen использует data image-picker. Отдельной задачей выделить domain-интерфейсы действий, уведомлений и выбора вложений; преобразование черновиков в HTTP-body и платформенные реализации оставить в data.

## Известные падения тестов: базовый уровень группы 6–10

Отдельной задачей исправить тестовую инфраструктуру и несоответствия ожиданий UI. Эти падения зафиксированы до разделения моделей; их нельзя учитывать как новые регрессии при неизменном составе и причине:

- `test/features/chat/conversation_menu_test.dart`: 5 падений, отсутствует `Provider<ProfileCubit>`.
- `test/features/inbox/inbox_screen_test.dart`: 1 падение (`creates a quick inbox task on a narrow screen`).
- Тесты dashboard: 4 падения базового уровня:
  - `dashboard_editor_test.dart`: `header buttons edit shared dashboard, add, cancel and save on a narrow phone`;
  - `dashboard_resource_widget_test.dart`: `resource rings aggregate pairs, switch to task rings and filter labels`;
  - `dashboard_widget_panel_test.dart`: `AI renders teammate overdue recommendations instead of a quote`;
  - `dashboard_widget_panel_test.dart`: `swiping inside expanded recommendations scrolls dashboard`.
  При шаге dashboard сравнить также причины падений, а не только количество.

## Inbox: типизированный detail с сохранением дополнительных полей

`InboxTaskDetail.unknownDetailFields: Map<String, dynamic>` — осознанное исключение: в API-фикстуре `test/features/inbox/inbox_repository_test.dart` есть `detail.files`, и HTTP-тест требует сохранить его при PATCH и копировании. `description`, `labels` и `completed` выделены в явные поля; остальные ключи проходят без изменений. После уточнения контракта detail поднять дополнительные данные (включая файлы) в типизированные сущности отдельной задачей. Не удалять карту без замены сохранения данных.

`lib/features/inbox/presentation/cubit/inbox_cubit.dart` → `data/repositories/inbox_repository_impl.dart` (`InboxException`) и `data/services/inbox_home_widget_service.dart` (`InboxHomeWidgetService`): отдельными задачами перенести исключение в domain и выделить domain-интерфейс обновления домашнего виджета с платформенной реализацией в data.

## Storage: гибридное содержимое резюме встречи

`StorageSummary.content` имеет тип `StorageSummaryContent` с явными полями верхнего уровня. До разделения UI читал: `participantDetails` ×1, `keyDecisions` ×1, `allEntries` ×1, `duration` ×2. Динамическими остаются:

- `participantDetails: Map<String, dynamic>`: словарь участников по идентификаторам, вложенный `name` читается дважды;
- `keyDecisions` и `allEntries: List<Map<String, dynamic>>`: записи решений/стенограммы с `userId` ×2, `createdTask` ×1, `file` ×1, `text` ×1, `id` ×1;
- вложенная задача: `id` ×2, `title` ×1;
- вложенный файл: `dataUrl` ×2, `name` ×3, `mimeType` ×2.

Глубина достигает трёх уровней объектов от content. Отдельной задачей уточнить контракты участников и разных форм записей, затем заменить динамические части чистыми типами. `duration: String?` — DTO сохраняет текущее текстовое представление через toString; единицы и числовой формат API пока не установлены.

## Storage: presentation → data

- `lib/features/storage/presentation/storage_summary_screen.dart` использует `data/storage_collector.dart` для вложенных динамических объектов и классификации файлов. После типизации содержимого резюме убрать разбор объектов из UI, классификацию предоставить через domain-контракт.
- `lib/features/storage/presentation/storage_screen.dart` использует `features/chat/data/services/chat_media_payload.dart` (`openStorageLink`); отдельно выделить интерфейс открытия ссылок/медиа.
- `lib/features/storage/presentation/messenger_storage_screen.dart` использует `features/chat/data/models/chat_conversation_model.dart`; заменить на domain-сущность при шаге chat.

`StorageException` уже находится в domain.

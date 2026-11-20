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

# Архитектурный долг

Эти зависимости presentation → data оставлены без изменения в шагах разделения сущностей и DTO. Каждую следует устранить отдельной задачей, сохранив тип исключения и поведение обработки ошибок.

| Исключение | Текущий путь зависимости | Предлагаемая отдельная задача |
|---|---|---|
| `AuthException` | `lib/features/auth/presentation/cubit/auth_cubit.dart` → `lib/features/auth/data/repositories/auth_repository_impl.dart` | Перенести исключение в `lib/features/auth/domain/exceptions/auth_exception.dart`; обновить импорты реализации, Cubit и тестов. |
| `ProfileException` | `lib/features/profile/presentation/cubit/profile_cubit.dart` → `lib/features/profile/data/repositories/profile_repository_impl.dart` | Перенести исключение в `lib/features/profile/domain/exceptions/profile_exception.dart`; обновить импорты реализации, Cubit и тестов. |
| `WorkspaceException` | `lib/features/workspaces/presentation/cubit/workspace_cubit.dart` → `lib/features/workspaces/data/repositories/workspace_repository_impl.dart` | Перенести исключение в `lib/features/workspaces/domain/exceptions/workspace_exception.dart`; обновить импорты реализации, Cubit и тестов. |

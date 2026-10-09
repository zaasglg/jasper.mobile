import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/dio_factory.dart';
import '../network/user_avatar_repository.dart';
import '../storage/auth_token_storage.dart';
import '../storage/workspace_selection_storage.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/inbox/data/repositories/inbox_repository_impl.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/presentation/cubit/chat_cubit.dart';
import '../../features/inbox/domain/repositories/inbox_repository.dart';
import '../../features/inbox/presentation/cubit/inbox_cubit.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/kanban/data/repositories/kanban_repository_impl.dart';
import '../../features/kanban/domain/repositories/kanban_repository.dart';
import '../../features/kanban/domain/entities/kanban_board_cache.dart';
import '../../features/kanban/presentation/cubit/kanban_cubit.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/projects/data/repositories/project_repository_impl.dart';
import '../../features/projects/data/repositories/project_task_repository_impl.dart';
import '../../features/projects/domain/repositories/project_repository.dart';
import '../../features/projects/domain/repositories/project_task_repository.dart';
import '../../features/projects/presentation/cubit/projects_cubit.dart';
import '../../features/tasks/data/repositories/my_tasks_repository_impl.dart';
import '../../features/tasks/data/repositories/task_details_repository_impl.dart';
import '../../features/tasks/data/storage/my_task_fields_storage_impl.dart';
import '../../features/tasks/domain/repositories/my_task_fields_storage.dart';
import '../../features/tasks/domain/repositories/my_tasks_repository.dart';
import '../../features/tasks/domain/repositories/task_details_repository.dart';
import '../../features/tasks/presentation/cubit/my_tasks_cubit.dart';
import '../../features/tasks/presentation/cubit/task_details_cubit.dart';
import '../../features/workspaces/data/repositories/workspace_repository_impl.dart';
import '../../features/workspaces/domain/repositories/workspace_repository.dart';
import '../../features/workspaces/presentation/cubit/workspace_cubit.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Core
  sl.registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new);
  sl.registerLazySingleton<AuthTokenStorage>(() => AuthTokenStorage(sl()));
  sl.registerLazySingleton<WorkspaceSelectionStorage>(
    () => WorkspaceSelectionStorage(sl()),
  );
  sl.registerLazySingleton<Dio>(() => createDio(sl()));
  sl.registerLazySingleton<UserAvatarRepository>(
    () => UserAvatarRepository(sl(), sl()),
  );

  // Auth
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      dio: sl(),
      storage: sl(),
      workspaceSelectionStorage: sl(),
    ),
  );
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl()));

  // Inbox
  sl.registerLazySingleton<InboxRepository>(() => InboxRepositoryImpl(sl()));
  sl.registerFactory<InboxCubit>(() => InboxCubit(sl()));

  // Messenger
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(sl(), sl()),
  );
  sl.registerFactory<ChatCubit>(() => ChatCubit(sl()));

  // Profile
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl()),
  );
  sl.registerFactory<ProfileCubit>(() => ProfileCubit(sl()));

  // Projects
  sl.registerLazySingleton<ProjectRepository>(
    () => ProjectRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProjectTaskRepository>(
    () => ProjectTaskRepositoryImpl(sl()),
  );
  sl.registerFactory<ProjectsCubit>(
    () => ProjectsCubit(sl(), taskRepository: sl()),
  );

  // Project Kanban
  sl.registerFactory<KanbanRepository>(() => KanbanRepositoryImpl(sl()));
  sl.registerLazySingleton<KanbanBoardCache>(KanbanBoardCache.new);
  sl.registerFactory<KanbanCubit>(() => KanbanCubit(sl(), cache: sl()));

  // Dashboard tasks
  sl.registerLazySingleton<MyTasksRepository>(
    () => MyTasksRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<MyTaskFieldsStorage>(
    () => MyTaskFieldsStorageImpl(sl()),
  );
  sl.registerFactory<MyTasksCubit>(
    () => MyTasksCubit(repository: sl(), fieldsStorage: sl()),
  );
  sl.registerLazySingleton<TaskDetailsRepository>(
    () => TaskDetailsRepositoryImpl(sl()),
  );
  sl.registerFactory<TaskDetailsCubit>(() => TaskDetailsCubit(sl(), sl()));

  // Workspaces
  sl.registerLazySingleton<WorkspaceRepository>(
    () => WorkspaceRepositoryImpl(sl()),
  );
  sl.registerFactory<WorkspaceCubit>(
    () => WorkspaceCubit(repository: sl(), selectionStorage: sl()),
  );
}

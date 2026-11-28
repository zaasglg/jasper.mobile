import '../../features/calls/data/call_protocol_repository_impl.dart';
import '../../features/calls/domain/call_protocol_repository.dart';
import '../../features/calls/presentation/protocol/call_protocol_cubit.dart';
import '../../features/planner/domain/repositories/planner_week_order_repository.dart';
import '../../features/planner/data/repositories/planner_week_order_repository_impl.dart';
import '../../features/planner/presentation/cubit/planner_week_order_cubit.dart';
import '../../features/dashboard/domain/daily_quote_repository.dart';
import '../../features/dashboard/data/daily_quote_repository_impl.dart';
import '../../features/planner/domain/repositories/ai_day_plan_repository.dart';
import '../../features/planner/data/repositories/ai_day_plan_repository_impl.dart';
import '../../features/notifications/domain/notification_preferences_repository.dart';
import '../../features/notifications/data/notification_preferences_repository_impl.dart';
import '../../features/notifications/presentation/notification_preferences_cubit.dart';
import '../localization/locale_cubit.dart';
import '../localization/app_translations.dart';
import '../../features/assistant/domain/repositories/assistant_history_repository.dart';
import '../../features/assistant/data/repositories/assistant_history_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_cubit.dart';
import '../../features/chat/data/services/channel_photo_picker.dart';
import '../../features/chat/domain/repositories/channel_image_repository.dart';
import '../../features/planner/domain/repositories/task_icon_repository.dart';
import '../../features/planner/data/repositories/task_icon_repository_impl.dart';
import '../../features/notifications/data/native_push_gateway.dart';
import '../../features/notifications/domain/push_gateway.dart';
import '../../features/notifications/presentation/push_cubit.dart';
import '../../features/planner/data/repositories/google_calendar_repository_impl.dart';
import '../../features/planner/domain/repositories/google_calendar_repository.dart';
import '../../features/calls/domain/call_repository.dart';
import '../../features/calls/data/call_repository_impl.dart';
import '../../features/calls/data/livekit_call_media.dart';
import '../../features/calls/presentation/call_cubit.dart';
import '../../features/assistant/data/services/assistant_actions.dart';
import '../../features/dashboard/data/mentions_read_storage.dart';
import '../../features/tasks/data/repositories/task_creation_repository_impl.dart';
import '../../features/tasks/domain/repositories/task_creation_repository.dart';
import '../../features/tasks/presentation/cubit/task_creation_cubit.dart';
import '../../features/dashboard/data/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/dashboard_repository.dart';
import '../../features/dashboard/presentation/cubit/dashboard_layout_cubit.dart';
import '../../features/storage/data/storage_repository_impl.dart';
import '../../features/storage/domain/storage_repository.dart';
import '../../features/activity/data/activity_repository.dart';
import '../../features/collaboration/data/collaboration_repository_impl.dart';
import '../../features/collaboration/domain/collaboration_repository.dart';
import '../../features/kanban/data/storage/card_view_storage.dart';
import '../../features/assistant/data/repositories/assistant_repository_impl.dart';
import '../../features/assistant/data/services/device_assistant_voice.dart';
import '../../features/assistant/domain/repositories/assistant_repository.dart';
import '../../features/assistant/domain/services/assistant_voice.dart';
import '../../features/assistant/presentation/cubit/assistant_cubit.dart';
import '../../features/planner/data/repositories/planner_repository_impl.dart';
import '../../features/planner/domain/repositories/planner_repository.dart';
import '../../features/planner/presentation/cubit/planner_cubit.dart';
import 'package:dio/dio.dart';
import '../../features/search/data/search_repository.dart';
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
import '../../features/kanban/data/repositories/task_move_repository_impl.dart';
import '../../features/kanban/domain/repositories/task_move_repository.dart';
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
import '../../features/qr_login/data/qr_login_repository_impl.dart';
import '../../features/qr_login/domain/qr_login_repository.dart';
import '../../features/qr_login/presentation/cubit/qr_login_cubit.dart';
import '../../features/qr_login/presentation/cubit/qr_sessions_cubit.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  final preferences = await SharedPreferences.getInstance();
  await AppTranslations.load();
  sl.registerSingleton<SharedPreferences>(preferences);
  sl.registerSingleton<ThemeCubit>(
    ThemeCubit(preferences),
    dispose: (cubit) => cubit.close(),
  );
  // Core
  sl.registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new);
  sl.registerLazySingleton<MentionsReadStorage>(
    () => MentionsReadStorage(sl()),
  );
  sl.registerLazySingleton<AuthTokenStorage>(() => AuthTokenStorage(sl()));
  sl.registerLazySingleton<WorkspaceSelectionStorage>(
    () => WorkspaceSelectionStorage(sl()),
  );
  sl.registerLazySingleton<Dio>(() => createDio(sl(), workspaceStorage: sl()));
  sl.registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(sl()));
  sl.registerLazySingleton<UserAvatarRepository>(
    () => UserAvatarRepository(sl(), sl()),
  );

  sl.registerLazySingleton<CollaborationRepository>(
    () => CollaborationRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<ActivityRepository>(
    () => ActivityRepository(sl(), sl()),
  );

  sl.registerLazySingleton<StorageRepository>(
    () => StorageRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton<PlannerWeekOrderRepository>(
    () => PlannerWeekOrderRepositoryImpl(preferences, sl()),
  );
  sl.registerFactory<PlannerWeekOrderCubit>(() => PlannerWeekOrderCubit(sl()));

  sl.registerLazySingleton<DailyQuoteRepository>(
    () => DailyQuoteRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(sl()),
  );
  sl.registerFactory<DashboardLayoutCubit>(() => DashboardLayoutCubit(sl()));

  sl.registerLazySingleton<TaskCreationRepository>(
    () => TaskCreationRepositoryImpl(sl()),
  );
  sl.registerFactory<TaskCreationCubit>(
    () => TaskCreationCubit(sl(), workspaceStorage: sl()),
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
  sl.registerLazySingleton<QrLoginRepositoryImpl>(
    () => QrLoginRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<QrLoginRepository>(
    () => sl<QrLoginRepositoryImpl>(),
  );
  sl.registerLazySingleton<QrSessionsRepository>(
    () => sl<QrLoginRepositoryImpl>(),
  );
  sl.registerFactory<QrLoginCubit>(() => QrLoginCubit(sl()));
  sl.registerFactory<QrSessionsCubit>(() => QrSessionsCubit(sl()));

  // Inbox
  sl.registerLazySingleton<InboxRepository>(() => InboxRepositoryImpl(sl()));
  sl.registerFactory<InboxCubit>(() => InboxCubit(sl()));

  // Messenger
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(sl(), sl()),
    dispose: (repository) => (repository as ChatRepositoryImpl).dispose(),
  );
  sl.registerLazySingleton<ChannelPhotoPicker>(
    () => GalleryChannelPhotoPicker(),
  );
  sl.registerFactory<ChatCubit>(() => ChatCubit(sl()));

  // Profile
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProfileLocaleRepository>(
    () => sl<ProfileRepository>() as ProfileLocaleRepository,
  );
  sl.registerSingleton<LocaleCubit>(
    LocaleCubit(sl(), sl(), preferences, sl()),
    dispose: (cubit) => cubit.close(),
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

  sl.registerLazySingleton<CardViewStorage>(
    () => CardViewStorage(sl(), dio: sl(), tokenStorage: sl()),
  );

  // Project Kanban
  sl.registerFactory<KanbanRepository>(() => KanbanRepositoryImpl(sl()));
  sl.registerLazySingleton<TaskMoveRepository>(
    () => TaskMoveRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<KanbanBoardCache>(KanbanBoardCache.new);
  sl.registerFactory<KanbanCubit>(
    () => KanbanCubit(sl(), cache: sl(), taskMoveRepository: sl()),
  );

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
  sl.registerLazySingleton<TaskResourceReadRepository>(
    () => sl<TaskDetailsRepository>() as TaskResourceReadRepository,
  );
  sl.registerFactory<TaskDetailsCubit>(() => TaskDetailsCubit(sl(), sl()));

  sl.registerLazySingleton<CallProtocolRepository>(
    () => CallProtocolRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<CallRepository>(() => CallRepositoryImpl(sl()));
  sl.registerLazySingleton<CallCubit>(() {
    final media = LiveKitCallMedia(
      beforeCapture: () async {
        await sl<AssistantVoice>().stop();
        await sl<AssistantVoice>().stopSpeaking();
      },
    );
    return CallCubit(sl(), media, protocol: CallProtocolCubit(sl(), media));
  }, dispose: (cubit) => cubit.close());

  // Voice assistant
  sl.registerLazySingleton<AssistantRepository>(
    () => AssistantRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<AssistantHistoryRepository>(
    () => AssistantHistoryRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<AssistantVoice>(DeviceAssistantVoice.new);
  sl.registerFactory<AssistantCubit>(
    () => AssistantCubit(
      sl(),
      sl(),
      sl(),
      actions: AssistantActions(sl(), sl()),
      history: sl(),
    ),
  );

  sl.registerLazySingleton<GoogleCalendarRepository>(
    () => GoogleCalendarRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<NotificationPreferencesRepository>(
    () => NotificationPreferencesRepositoryImpl(preferences, sl()),
  );
  sl.registerLazySingleton<NotificationPreferencesCubit>(
    () => NotificationPreferencesCubit(sl(), sl(), sl()),
    dispose: (cubit) => cubit.close(),
  );
  sl.registerLazySingleton<PushGateway>(NativePushGateway.new);
  sl.registerLazySingleton<PushCubit>(() => PushCubit(sl()));

  // Planner
  sl.registerLazySingleton<AiDayPlanRepository>(
    () => AiDayPlanRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<PlannerRepository>(
    () => PlannerRepositoryImpl(sl()),
  );
  sl.registerFactory<TaskIconRepository>(() => TaskIconRepositoryImpl(sl()));
  sl.registerFactory<PlannerCubit>(
    () => PlannerCubit(sl(), iconRepository: sl()),
  );

  // Workspaces
  sl.registerLazySingleton<WorkspaceRepository>(
    () => WorkspaceRepositoryImpl(sl()),
  );
  sl.registerFactory<WorkspaceCubit>(
    () => WorkspaceCubit(repository: sl(), selectionStorage: sl()),
  );
}

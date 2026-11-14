import '../../features/projects/presentation/screens/project_epics_screen.dart';
import '../../features/collaboration/presentation/project_participants_screen.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/calls/presentation/call_screen.dart';
import 'package:flutter/widgets.dart';
import '../../features/tasks/presentation/screens/task_creation_screen.dart';
import '../../features/tasks/presentation/cubit/task_creation_cubit.dart';
import '../../features/storage/presentation/messenger_storage_screen.dart';
import '../../features/storage/data/storage_models.dart';
import '../../features/storage/presentation/storage_screen.dart';
import '../../features/storage/presentation/storage_file_screen.dart';
import '../../features/storage/presentation/storage_summary_screen.dart';
import '../../features/chat/presentation/screens/messenger_settings_screen.dart';
import '../../features/activity/data/activity_repository.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/collaboration/data/collaboration_models.dart';
import '../../features/collaboration/presentation/space_management_screen.dart';
import '../../features/collaboration/presentation/archive_screen.dart';
import '../../features/assistant/presentation/cubit/assistant_cubit.dart';
import '../../features/assistant/presentation/screens/assistant_screen.dart';
import '../../features/planner/presentation/cubit/planner_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_session.dart';
import '../di/service_locator.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/projects/presentation/screens/projects_screen.dart';
import '../../features/projects/presentation/screens/project_details_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversation_screen.dart';
import '../../features/chat/data/models/chat_conversation_model.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/presentation/cubit/chat_cubit.dart';
import '../../features/chat/presentation/cubit/conversation_cubit.dart';
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/inbox/presentation/cubit/inbox_cubit.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/search/data/search_repository.dart';
import '../../features/search/presentation/search_cubit.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/workspaces/presentation/cubit/workspace_cubit.dart';
import '../../features/workspaces/presentation/cubit/workspace_state.dart';
import '../../features/planner/presentation/screens/planner_screen.dart';
import '../../features/projects/data/models/project_task_model.dart';
import '../../features/projects/data/models/project_model.dart';
import '../../features/kanban/presentation/cubit/kanban_cubit.dart';
import '../../features/tasks/presentation/screens/task_details_screen.dart';
import '../../features/tasks/presentation/cubit/task_details_cubit.dart';
import '../../features/qr_login/presentation/cubit/qr_login_cubit.dart';
import '../../features/qr_login/presentation/cubit/qr_sessions_cubit.dart';
import '../../features/qr_login/presentation/screens/qr_login_screen.dart';
import '../../features/qr_login/presentation/screens/qr_sessions_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: authSession,
  redirect: (context, state) {
    if (authSession.requiresLogin && state.matchedLocation != '/login') {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/call', builder: (context, state) => const CallScreen()),
    GoRoute(
      path: '/messenger-storage',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<ChatCubit>()..load(),
        child: const MessengerStorageScreen(),
      ),
    ),
    GoRoute(
      path: '/storage',
      redirect: (context, state) =>
          state.extra is StorageScope ? null : '/projects',
      builder: (context, state) =>
          StorageScreen(scope: state.extra! as StorageScope),
    ),
    GoRoute(
      path: '/storage-file',
      redirect: (context, state) =>
          state.extra is (StorageScope, StorageItem) ? null : '/projects',
      builder: (context, state) {
        final args = state.extra! as (StorageScope, StorageItem);
        return StorageFileScreen(scope: args.$1, item: args.$2);
      },
    ),
    GoRoute(
      path: '/storage-summary',
      redirect: (context, state) =>
          state.extra is (StorageScope, StorageSummary) ? null : '/projects',
      builder: (context, state) {
        final args = state.extra! as (StorageScope, StorageSummary);
        return StorageSummaryScreen(scope: args.$1, summary: args.$2);
      },
    ),
    GoRoute(
      path: '/messenger-settings',
      builder: (context, state) => const MessengerSettingsScreen(),
    ),
    GoRoute(
      path: '/activity/:kind',
      builder: (context, state) => ActivityScreen(
        kind: ActivityKind.values.firstWhere(
          (e) => e.name == state.pathParameters['kind'],
          orElse: () => ActivityKind.notifications,
        ),
      ),
    ),
    GoRoute(
      path: '/projects/:id/participants',
      builder: (context, state) =>
          ProjectParticipantsScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/projects/:id/epics',
      builder: (context, state) => ProjectEpicsScreen(
        projectId: state.pathParameters['id']!,
        boardCubit: state.extra is KanbanCubit
            ? state.extra! as KanbanCubit
            : null,
      ),
    ),
    GoRoute(
      path: '/manage/:kind/:id',
      builder: (context, state) => SpaceManagementScreen(
        kind: state.pathParameters['kind'] == 'projects'
            ? SpaceKind.project
            : SpaceKind.workspace,
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/archives/:kind',
      builder: (context, state) => ArchiveScreen(
        kind: state.pathParameters['kind'] == 'projects'
            ? SpaceKind.project
            : SpaceKind.workspace,
        workspaceId: state.uri.queryParameters['workspaceId'],
      ),
    ),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) => BlocProvider<AuthCubit>(
        create: (_) => sl<AuthCubit>(),
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/assistant',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<AssistantCubit>()
          ..currentProjectId = state.uri.queryParameters['projectId']
          ..currentProjectName = state.uri.queryParameters['projectName']
          ..initialize(),
        child: AssistantScreen(
          startVoice: state.uri.queryParameters['voice'] == 'true',
          initialCommand: state.extra is String ? state.extra as String : null,
        ),
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/qr-sessions',
      redirect: (context, state) =>
          state.extra is ({String name, String email}) ? null : '/profile',
      builder: (context, state) {
        final account = state.extra! as ({String name, String email});
        return BlocProvider<QrSessionsCubit>(
          create: (_) => sl<QrSessionsCubit>()..load(),
          child: QrSessionsScreen(
            accountName: account.name,
            email: account.email,
          ),
        );
      },
    ),
    GoRoute(
      path: '/qr-login',
      redirect: (context, state) =>
          state.extra is ({String name, String email}) ? null : '/profile',
      builder: (context, state) {
        final account = state.extra! as ({String name, String email});
        return BlocProvider<QrLoginCubit>(
          create: (_) => sl<QrLoginCubit>(),
          child: QrLoginScreen(accountName: account.name, email: account.email),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        final data = state.extra is SettingsNavigationData
            ? state.extra! as SettingsNavigationData
            : null;
        final voice =
            data?.voice ??
            (state.extra is VoiceSettingsController
                ? state.extra! as VoiceSettingsController
                : null);
        if (data != null) {
          return SettingsScreen(
            voiceController: voice,
            workspaceCubit: data.workspace,
          );
        }
        return BlocProvider<WorkspaceCubit>(
          create: (_) => sl<WorkspaceCubit>()..load(),
          child: Builder(
            builder: (context) => SettingsScreen(
              voiceController: voice,
              workspaceCubit: context.read<WorkspaceCubit>(),
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/tasks/new',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<TaskCreationCubit>()
          ..initialize(workspaceId: state.uri.queryParameters['workspaceId']),
        child: const TaskCreationScreen(),
      ),
    ),
    GoRoute(
      path: '/tasks/:taskId',
      builder: (context, state) {
        final taskId = state.pathParameters['taskId'] ?? '';
        final task = state.extra is ProjectTaskModel
            ? state.extra! as ProjectTaskModel
            : null;
        // Task details is a root route outside MainShell, so its shared
        // dashboard header needs its own workspace and profile providers.
        return MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceCubit>(
              create: (_) => sl<WorkspaceCubit>()..load(),
            ),
            BlocProvider<ProfileCubit>(
              create: (_) => sl<ProfileCubit>()..load(),
            ),
            BlocProvider<TaskDetailsCubit>(
              create: (_) =>
                  sl<TaskDetailsCubit>()..load(taskId, initialTask: task),
            ),
          ],
          child: TaskDetailsScreen(taskId: taskId, task: task),
        );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        final branchCount = navigationShell.route.branches.length;
        final safeIndex = navigationShell.currentIndex.clamp(
          0,
          branchCount - 1,
        );

        return MainShell(
          currentIndex: safeIndex,
          onTap: (index) {
            if (index < 0 || index >= branchCount) return;
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          child: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
              routes: [
                GoRoute(
                  path: 'search',
                  builder: (context, state) => BlocProvider(
                    create: (context) {
                      final workspace = context.read<WorkspaceCubit>().state;
                      return SearchCubit(
                        sl<SearchRepository>(),
                        workspace is WorkspaceLoaded
                            ? workspace.selected?.id ?? ''
                            : '',
                      );
                    },
                    child: const SearchScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectsScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: ':projectId',
                  builder: (context, state) {
                    final projectId = state.pathParameters['projectId'] ?? '';
                    return BlocProvider<KanbanCubit>(
                      create: (_) => sl<KanbanCubit>()..load(projectId),
                      child: ProjectDetailsScreen(
                        projectId: projectId,
                        initialProject: state.extra is ProjectModel
                            ? state.extra! as ProjectModel
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messenger',
              builder: (context, state) => BlocProvider<ChatCubit>(
                create: (_) => sl<ChatCubit>()..load(),
                child: const ChatScreen(),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: ':conversationId',
                  builder: (context, state) {
                    final fallbackId =
                        state.pathParameters['conversationId'] ?? '';
                    final conversation = state.extra is ChatConversationModel
                        ? state.extra! as ChatConversationModel
                        : ChatConversationModel(
                            id: fallbackId,
                            threadId: fallbackId,
                            title: 'Переписка',
                            isChannel: false,
                          );
                    return BlocProvider<ConversationCubit>(
                      create: (_) =>
                          ConversationCubit(sl<ChatRepository>(), conversation)
                            ..load(),
                      child: ConversationScreen(
                        conversation: conversation,
                        initialMessageId:
                            state.uri.queryParameters['messageId'],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inbox',
              builder: (context, state) => BlocProvider<InboxCubit>(
                create: (_) => sl<InboxCubit>()..load(),
                child: InboxScreen(
                  composeRequest: state.uri.queryParameters['compose'],
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/planner',
              builder: (context, state) => BlocProvider(
                create: (_) => sl<PlannerCubit>(),
                child: const PlannerScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

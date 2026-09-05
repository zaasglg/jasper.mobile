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
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/inbox/presentation/cubit/inbox_cubit.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/planner/presentation/screens/planner_screen.dart';
import '../../features/projects/data/models/project_task_model.dart';
import '../../features/projects/data/models/project_model.dart';
import '../../features/kanban/presentation/cubit/kanban_cubit.dart';
import '../../features/tasks/presentation/screens/task_details_screen.dart';
import '../../features/tasks/presentation/cubit/task_details_cubit.dart';

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
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) => BlocProvider<AuthCubit>(
        create: (_) => sl<AuthCubit>(),
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/tasks/:taskId',
      builder: (context, state) {
        final taskId = state.pathParameters['taskId'] ?? '';
        final task = state.extra is ProjectTaskModel
            ? state.extra! as ProjectTaskModel
            : null;
        return BlocProvider<TaskDetailsCubit>(
          create: (_) =>
              sl<TaskDetailsCubit>()..load(taskId, initialTask: task),
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
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inbox',
              builder: (context, state) => BlocProvider<InboxCubit>(
                create: (_) => sl<InboxCubit>()..load(),
                child: const InboxScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/planner',
              builder: (context, state) => const PlannerScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

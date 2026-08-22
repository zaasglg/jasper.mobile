import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../di/service_locator.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/projects/presentation/screens/projects_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/planner/presentation/screens/planner_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
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
              builder: (context, state) => const InboxScreen(),
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

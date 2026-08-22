import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../../projects/presentation/widgets/create_project_sheet.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../widgets/app_drawer.dart';

/// Root shell that hosts the bottom navigation bar and the active tab's
/// content (provided by [child], typically a go_router StatefulNavigationShell).
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTap,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  static void openDrawer() => scaffoldKey.currentState?.openDrawer();

  static const Color _inactive = Color(0xFF9AA0A6);
  static const Color _active = Color(0xFF5B5FEF);

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(
        icon: Icon(LucideIcons.layoutDashboard, color: _inactive),
        selectedIcon: Icon(LucideIcons.layoutDashboard, color: _active),
        label: 'Дашборд',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.columns3, color: _inactive),
        selectedIcon: Icon(LucideIcons.columns3, color: _active),
        label: 'Проекты',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.messageCircle, color: _inactive),
        selectedIcon: Icon(LucideIcons.messageCircle, color: _active),
        label: 'Мессенджер',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.inbox, color: _inactive),
        selectedIcon: Icon(LucideIcons.inbox, color: _active),
        label: 'Инбокс',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.calendarClock, color: _inactive),
        selectedIcon: Icon(LucideIcons.calendarClock, color: _active),
        label: 'Ежедневник',
      ),
    ];

    final workspaceCubit = sl<WorkspaceCubit>()..load();
    final projectsCubit = sl<ProjectsCubit>();
    final workspaceState = workspaceCubit.state;
    if (workspaceState is WorkspaceLoaded &&
        workspaceState.selected != null &&
        projectsCubit.state.workspaceId != workspaceState.selected!.id) {
      projectsCubit.loadForWorkspace(workspaceState.selected!.id);
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<WorkspaceCubit>.value(value: workspaceCubit),
        BlocProvider<ProjectsCubit>.value(value: projectsCubit),
      ],
      child: BlocListener<WorkspaceCubit, WorkspaceState>(
        listenWhen: (previous, current) {
          final previousId = previous is WorkspaceLoaded
              ? previous.selected?.id
              : null;
          final currentId = current is WorkspaceLoaded
              ? current.selected?.id
              : null;
          return currentId != null && currentId != previousId;
        },
        listener: (context, state) {
          final selected = (state as WorkspaceLoaded).selected;
          if (selected != null) {
            context.read<ProjectsCubit>().loadForWorkspace(selected.id);
          }
        },
        child: Builder(
          builder: (shellContext) => Scaffold(
            key: scaffoldKey,
            drawer: AppDrawer(
              onCreateProject: () => showCreateProjectFlow(shellContext),
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: onTap,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              indicatorColor: _active.withValues(alpha: 0.12),
              elevation: 0,
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }
}

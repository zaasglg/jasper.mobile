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
class MainShell extends StatefulWidget {
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
  static const Color _active = Color(0xFF6D5FE0);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final WorkspaceCubit _workspaceCubit;
  late final ProjectsCubit _projectsCubit;

  @override
  void initState() {
    super.initState();
    _workspaceCubit = sl<WorkspaceCubit>()..load();
    _projectsCubit = sl<ProjectsCubit>();
  }

  @override
  void dispose() {
    _workspaceCubit.close();
    _projectsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(
        icon: Icon(LucideIcons.layoutDashboard, color: MainShell._inactive),
        selectedIcon: Icon(
          LucideIcons.layoutDashboard,
          color: MainShell._active,
        ),
        label: 'Дашборд',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.columns3, color: MainShell._inactive),
        selectedIcon: Icon(LucideIcons.columns3, color: MainShell._active),
        label: 'Проекты',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.messageCircle, color: MainShell._inactive),
        selectedIcon: Icon(LucideIcons.messageCircle, color: MainShell._active),
        label: 'Мессенджер',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.inbox, color: MainShell._inactive),
        selectedIcon: Icon(LucideIcons.inbox, color: MainShell._active),
        label: 'Инбокс',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.calendarClock, color: MainShell._inactive),
        selectedIcon: Icon(LucideIcons.calendarClock, color: MainShell._active),
        label: 'Ежедневник',
      ),
    ];

    return MultiBlocProvider(
      providers: [
        BlocProvider<WorkspaceCubit>.value(value: _workspaceCubit),
        BlocProvider<ProjectsCubit>.value(value: _projectsCubit),
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
            key: MainShell.scaffoldKey,
            drawer: AppDrawer(
              onCreateProject: () => showCreateProjectFlow(shellContext),
            ),
            body: widget.child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: widget.currentIndex.clamp(
                0,
                destinations.length - 1,
              ),
              onDestinationSelected: widget.onTap,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              indicatorColor: MainShell._active.withValues(alpha: 0.12),
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../../projects/presentation/cubit/projects_state.dart';
import '../../../tasks/presentation/cubit/my_tasks_cubit.dart';
import '../../../inbox/presentation/cubit/inbox_cubit.dart';
import '../widgets/dashboard_app_bar.dart';
import '../widgets/dashboard_inbox_composer.dart';
import '../widgets/dashboard_projects_card.dart';
import '../widgets/dashboard_welcome_header.dart';
import '../../../tasks/presentation/widgets/my_tasks_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileCubit>(create: (_) => sl<ProfileCubit>()..load()),
        BlocProvider<MyTasksCubit>(
          create: (_) => sl<MyTasksCubit>()..initializeFields(),
        ),
        BlocProvider<InboxCubit>(create: (_) => sl<InboxCubit>()),
      ],
      child: const _DashboardCoordinator(),
    );
  }
}

class _DashboardCoordinator extends StatefulWidget {
  const _DashboardCoordinator();

  @override
  State<_DashboardCoordinator> createState() => _DashboardCoordinatorState();
}

class _DashboardCoordinatorState extends State<_DashboardCoordinator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTasks());
  }

  void _syncTasks() {
    if (!mounted) return;
    final profileState = context.read<ProfileCubit>().state;
    final projectsState = context.read<ProjectsCubit>().state;
    if (profileState is! ProfileLoaded ||
        projectsState.isLoading ||
        projectsState.workspaceId == null) {
      return;
    }
    context.read<MyTasksCubit>().configure(
      userId: profileState.profile.id,
      projects: projectsState.projects,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<ProfileCubit, ProfileState>(
          listener: (_, _) => _syncTasks(),
        ),
        BlocListener<ProjectsCubit, ProjectsState>(
          listener: (_, _) => _syncTasks(),
        ),
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: const DashboardAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<ProfileCubit, ProfileState>(
            buildWhen: (previous, current) => current is ProfileLoaded,
            builder: (context, state) {
              final name =
                  state is ProfileLoaded && state.profile.name.isNotEmpty
                  ? state.profile.name
                  : 'Пользователь';
              return DashboardWelcomeHeader(name: name);
            },
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: const <Widget>[
                  DashboardInboxComposer(),
                  SizedBox(height: 16),
                  DashboardProjectsCard(),
                  SizedBox(height: 16),
                  MyTasksWidget(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

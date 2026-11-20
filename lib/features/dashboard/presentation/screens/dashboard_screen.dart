import '../../../../core/widgets/app_snack_bar.dart';
import '../../../assistant/data/services/assistant_task_changes.dart';
import '../widgets/dashboard_expandable_content.dart';
import '../widgets/dashboard_widget_skeleton.dart';
import '../../../../core/theme/dashboard_surface.dart';
import 'package:go_router/go_router.dart';
import '../../../tasks/data/models/task_creation_models.dart';
import '../../../tasks/presentation/cubit/my_tasks_state.dart';
import '../../../projects/data/models/project_model.dart';
import 'dart:async';
import '../../domain/entities/dashboard_widget_slot.dart';
import '../cubit/dashboard_layout_cubit.dart';
import '../widgets/dashboard_widget_editor.dart';
import '../widgets/dashboard_edit_toolbar.dart';
import '../widgets/dashboard_collapsible_widget.dart';
import '../widgets/dashboard_widget_panel.dart';
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
import '../widgets/dashboard_welcome_header.dart';
import '../../../tasks/presentation/widgets/my_tasks_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<DashboardLayoutCubit>(
          create: (_) => sl<DashboardLayoutCubit>(),
        ),
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

class _DashboardCoordinatorState extends State<_DashboardCoordinator>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    assistantTaskChanges.addListener(_onAiTasksChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTasks());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final cubit = context.read<DashboardLayoutCubit>();
      if (!cubit.state.editing &&
          !cubit.state.saving &&
          !cubit.state.loading &&
          cubit.state.layout != null) {
        cubit.refreshConfig();
      }
    });
  }

  @override
  void dispose() {
    assistantTaskChanges.removeListener(_onAiTasksChanged);
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final cubit = context.read<DashboardLayoutCubit>();
      if (!cubit.state.editing && !cubit.state.saving) {
        cubit.configure(
          cubit.state.userId,
          cubit.state.workspaceId,
          refresh: true,
        );
      }
    }
  }

  void _onAiTasksChanged() {
    if (!mounted) return;
    context.read<DashboardLayoutCubit>().refreshContent();
  }

  void _syncTasks() {
    if (!mounted) return;
    final profileState = context.read<ProfileCubit>().state;
    final projectsState = context.read<ProjectsCubit>().state;
    if (profileState is! ProfileLoaded || projectsState.workspaceId == null) {
      context.read<DashboardLayoutCubit>().configure('', '');
    }
    if (profileState is! ProfileLoaded ||
        projectsState.isLoading ||
        projectsState.workspaceId == null) {
      return;
    }
    context.read<DashboardLayoutCubit>().configure(
      profileState.profile.id,
      projectsState.workspaceId!,
    );
    context.read<MyTasksCubit>().configure(
      userId: profileState.profile.id,
      projects: projectsState.projects,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<MyTasksCubit, MyTasksState>(
          listenWhen: (previous, current) =>
              previous.updatingTaskIds.isNotEmpty &&
              current.updatingTaskIds.isEmpty &&
              current.actionErrorMessage == null,
          listener: (_, _) =>
              context.read<DashboardLayoutCubit>().refreshContent(),
        ),
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
  Widget build(
    BuildContext context,
  ) => BlocConsumer<DashboardLayoutCubit, DashboardLayoutState>(
    listener: (context, state) {
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(state.error!),
          ),
        );
      }
    },
    builder: (context, state) {
      final cubit = context.read<DashboardLayoutCubit>();
      final projects = context.watch<ProjectsCubit>().state.projects;
      final slots =
          state.current?.ordered
              .where(
                (e) =>
                    e.visible &&
                    e.definition?.available == true &&
                    !(state.readOnly && e.id == 'activity'),
              )
              .toList() ??
          <DashboardWidgetSlot>[];
      return PopScope(
        canPop: !state.editing,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && state.editing) cubit.cancelEdit();
        },
        child: Scaffold(
          backgroundColor: DashboardSurface.background,
          appBar: const DashboardAppBar(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<ProfileCubit, ProfileState>(
                buildWhen: (previous, current) => current is ProfileLoaded,
                builder: (context, profile) => DashboardWelcomeHeader(
                  onEdit:
                      state.layout == null ||
                          state.loading ||
                          state.editing ||
                          state.saving ||
                          state.readOnly
                      ? null
                      : cubit.enterEdit,
                  onCreate: state.saving
                      ? null
                      : () async {
                          final uri = Uri(
                            path: '/tasks/new',
                            queryParameters: state.workspaceId.isEmpty
                                ? null
                                : {'workspaceId': state.workspaceId},
                          );
                          final created = await context
                              .push<TaskCreationResult>(uri.toString());
                          if (!context.mounted || created == null) return;
                          cubit.refreshContent();
                          context.read<MyTasksCubit>().refresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            appSnackBar(
                              context: context,
                              tone: created.orderWarning
                                  ? AppSnackBarTone.info
                                  : AppSnackBarTone.success,
                              content: Text(
                                created.orderWarning
                                    ? 'Задача создана. Не удалось обновить её порядок в колонке'
                                    : 'Задача создана',
                              ),
                            ),
                          );
                        },
                  name:
                      profile is ProfileLoaded &&
                          profile.profile.name.isNotEmpty
                      ? profile.profile.name
                      : 'Пользователь',
                ),
              ),
              if (state.editing)
                DashboardEditToolbar(
                  saving: state.saving,
                  onCancel: cubit.cancelEdit,
                  onSave: cubit.save,
                  onAdd: () => showDashboardWidgetPicker(context, cubit),
                  onReset: () => confirmDashboardReset(context, cubit),
                ),
              if (state.loading || state.saving)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: DashboardSurface.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: state.layout == null && state.error != null
                      ? Center(
                          child: TextButton(
                            onPressed: () => cubit.configure(
                              state.userId,
                              state.workspaceId,
                              refresh: true,
                            ),
                            child: const Text('Повторить загрузку дашборда'),
                          ),
                        )
                      : state.layout == null
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (var i = 0; i < 3; i++)
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: DashboardSurface.shadows,
                                ),
                                child: const DashboardWidgetSkeleton(),
                              ),
                          ],
                        )
                      : state.editing
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          buildDefaultDragHandles: false,
                          onReorderItem: cubit.reorder,
                          itemCount: slots.length,
                          footer: slots.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(30),
                                  child: Text('Добавьте первый виджет'),
                                )
                              : null,
                          itemBuilder: (context, index) => Padding(
                            key: ValueKey(slots[index].instanceId),
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    DashboardEditActions(
                                      slot: slots[index],
                                      cubit: cubit,
                                      projects: projects,
                                      index: index,
                                      count: slots.length,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await cubit.configure(
                              state.userId,
                              state.workspaceId,
                              refresh: true,
                            );
                            if (context.mounted) {
                              await context.read<MyTasksCubit>().refresh();
                            }
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                            itemCount: slots.isEmpty ? 2 : slots.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 20),
                                  child: DashboardInboxComposer(),
                                );
                              }
                              if (slots.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Добавьте виджеты через кнопку редактирования',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              final slot = slots[index - 1];
                              return Padding(
                                key: ValueKey(
                                  '${state.userId}:${state.workspaceId}:${slot.instanceId}',
                                ),
                                padding: const EdgeInsets.only(bottom: 20),
                                child: DashboardCollapsibleWidget(
                                  key: ValueKey('collapse-${slot.instanceId}'),
                                  title: switch (slot.id) {
                                    'kpi-group' => 'Общие данные',
                                    'daily-motivation' => 'AI рекомендации',
                                    'activity' => 'Последняя активность',
                                    _ => slot.definition?.title ?? slot.id,
                                  },
                                  icon: dashboardWidgetIcon(slot.id),
                                  child: _widget(
                                    context,
                                    slot,
                                    state,
                                    projects,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _widget(
    BuildContext context,
    DashboardWidgetSlot slot,
    DashboardLayoutState state,
    List<ProjectModel> projects,
  ) {
    final expandContent =
        !state.editing && MediaQuery.sizeOf(context).width < 600;
    final Widget content;
    if (slot.id == 'my-tasks') {
      content = MyTasksWidget(
        expandContent: !state.editing && MediaQuery.sizeOf(context).width < 600,
        key: ValueKey('${state.workspaceId}:${slot.instanceId}'),
        height: (slot.height ?? 344).clamp(344, 900).toDouble(),
      );
    } else {
      content = DashboardWidgetPanel(
        expandContent: !state.editing && MediaQuery.sizeOf(context).width < 600,
        key: ValueKey('${state.workspaceId}:${slot.instanceId}'),
        slot: slot,
        revision: state.revision,
        projects: projects,
        workspaceId: state.workspaceId,
        userId: state.userId,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: DashboardSurface.shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: expandContent
            ? DashboardExpandableContent(
                key: ValueKey(
                  '${state.workspaceId}:${slot.instanceId}:preview',
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}

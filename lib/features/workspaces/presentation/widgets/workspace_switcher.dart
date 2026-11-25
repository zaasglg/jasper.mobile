import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/workspace_cubit.dart';
import '../cubit/workspace_state.dart';

class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<WorkspaceCubit, WorkspaceState>(
    builder: (context, state) {
      final cubit = context.read<WorkspaceCubit>();
      final loaded = state is WorkspaceLoaded ? state : null;
      final colors = AppColors.of(context);
      return FTheme(
        data: Theme.of(context).brightness == Brightness.dark
            ? FTheme.neutral.dark.touch
            : FTheme.neutral.light.touch,
        child: FPopoverMenu(
          menuAnchor: Alignment.topLeft,
          childAnchor: Alignment.bottomLeft,
          maxHeight: MediaQuery.sizeOf(context).height * .6,
          menuBuilder: (context, controller, _) => [
            FItemGroup(
              children: [
                for (final workspace in loaded?.workspaces ?? [])
                  FItem(
                    title: Text(
                      workspace.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    suffix: workspace.id == loaded?.selected?.id
                        ? const Icon(LucideIcons.check, size: 16)
                        : null,
                    onPress: () {
                      controller.hide();
                      final changed = workspace.id != loaded?.selected?.id;
                      unawaited(cubit.select(workspace));
                      if (changed &&
                          GoRouter.of(context)
                              .routeInformationProvider
                              .value
                              .uri
                              .path
                              .startsWith('/projects/')) {
                        context.go('/projects');
                      }
                    },
                  ),
                if (loaded != null && loaded.workspaces.isEmpty)
                  FItem(
                    title: Text(tr(context, 'Доступных workspace пока нет')),
                  ),
                if (loaded == null)
                  FItem(
                    title: Text(
                      tr(
                        context,
                        state is WorkspaceFailure ? state.message : 'Загрузка…',
                      ),
                    ),
                  ),
                if (loaded?.refreshError != null)
                  FItem(title: Text(loaded!.refreshError!)),
              ],
            ),
            FItemGroup(
              children: [
                FItem(
                  prefix: const Icon(LucideIcons.plus, size: 16),
                  title: Text(tr(context, 'Создать workspace')),
                  onPress: () {
                    controller.hide();
                    _create(context, cubit);
                  },
                ),
                FItem(
                  prefix: const Icon(LucideIcons.archive, size: 16),
                  title: Text(tr(context, 'Архивированные')),
                  onPress: () {
                    controller.hide();
                    _archived(context, cubit);
                  },
                ),
              ],
            ),
          ],
          builder: (context, controller, _) => Tooltip(
            message: tr(context, 'Переключить workspace'),
            child: InkWell(
              key: const Key('workspace-switcher'),
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                controller.toggle();
                unawaited(cubit.load(force: true));
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        loaded?.selected?.name ??
                            tr(context, 'Рабочие пространства'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _create(BuildContext context, WorkspaceCubit cubit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _CreateWorkspace()),
    );
  }

  Future<void> _archived(BuildContext context, WorkspaceCubit cubit) async {
    unawaited(cubit.loadArchived());
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocBuilder<WorkspaceCubit, WorkspaceState>(
        bloc: cubit,
        builder: (context, state) {
          final loaded = state is WorkspaceLoaded ? state : null;
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text(tr(context, 'Архивированные'))),
                  if (loaded?.isLoadingArchived == true)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  if (loaded?.archivedError != null)
                    ListTile(
                      title: Text(loaded!.archivedError!),
                      trailing: IconButton(
                        tooltip: tr(context, 'Повторить'),
                        onPressed: cubit.loadArchived,
                        icon: const Icon(LucideIcons.refreshCw),
                      ),
                    ),
                  if (loaded != null &&
                      !loaded.isLoadingArchived &&
                      loaded.archivedError == null &&
                      loaded.archivedWorkspaces.isEmpty)
                    ListTile(
                      title: Text(tr(context, 'Нет архивированных workspace')),
                    ),
                  for (final workspace in loaded?.archivedWorkspaces ?? [])
                    ListTile(title: Text(workspace.name)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreateWorkspace extends StatefulWidget {
  const _CreateWorkspace();
  @override
  State<_CreateWorkspace> createState() => _CreateWorkspaceState();
}

class _CreateWorkspaceState extends State<_CreateWorkspace> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context.read<WorkspaceCubit>().createWorkspace(
      _name.text,
      '#6D5FE0',
    );
    if (mounted && saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          final loaded = state is WorkspaceLoaded ? state : null;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, 'Создать workspace'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    enabled: loaded?.isCreating != true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Название workspace'),
                    ),
                    onSubmitted: (_) {
                      if (loaded?.isCreating != true) _save();
                    },
                  ),
                  if (loaded?.creationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(loaded!.creationError!),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: loaded?.isCreating == true ? null : _save,
                    child: Text(tr(context, 'Создать')),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

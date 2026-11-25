import 'workspace_switcher.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../cubit/workspace_cubit.dart';
import '../cubit/workspace_state.dart';

/// Builds workspace-dependent screens only after a selection is available.
class WorkspaceAccessGate extends StatefulWidget {
  const WorkspaceAccessGate({
    super.key,
    required this.child,
    required this.onOpenMenu,
  });

  final Widget child;
  final VoidCallback onOpenMenu;

  @override
  State<WorkspaceAccessGate> createState() => _WorkspaceAccessGateState();
}

class _WorkspaceAccessGateState extends State<WorkspaceAccessGate> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    context.read<WorkspaceCubit>().createWorkspace(_name.text, '#6D5FE0');
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<WorkspaceCubit, WorkspaceState>(
    builder: (context, state) {
      if (state is WorkspaceLoaded && state.selected != null) {
        return widget.child;
      }
      final colors = AppColors.of(context);
      final loaded = state is WorkspaceLoaded ? state : null;
      final busy = loaded?.isCreating == true;
      return Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const WorkspaceSwitcher(),
          actions: [
            IconButton(
              tooltip: tr(context, 'Профиль'),
              onPressed: () => context.push('/profile'),
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
        body: state is WorkspaceInitial || state is WorkspaceLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          state is WorkspaceFailure
                              ? tr(context, 'Не удалось загрузить пространства')
                              : tr(context, 'Создайте первое пространство'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state is WorkspaceFailure
                              ? state.message
                              : tr(
                                  context,
                                  'В нём будут ваши проекты, задачи и обсуждения. Если вас пригласили в команду, примите приглашение и обновите список.',
                                ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.muted, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        if (loaded != null) ...[
                          TextField(
                            key: const Key('first-workspace-name'),
                            controller: _name,
                            enabled: !busy,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => busy ? null : _create(),
                            onChanged: (_) => context
                                .read<WorkspaceCubit>()
                                .clearCreationError(),
                            decoration: InputDecoration(
                              labelText: tr(context, 'Название пространства'),
                              hintText: tr(context, 'Например, Мои проекты'),
                              errorText: trn(context, loaded.creationError),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const Key('first-workspace-create'),
                            onPressed: busy ? null : _create,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                busy
                                    ? tr(context, 'Создаём…')
                                    : tr(context, 'Создать пространство'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (loaded.refreshError != null)
                            Text(
                              loaded.refreshError!,
                              style: TextStyle(color: colors.error),
                            ),
                        ],
                        TextButton(
                          onPressed: busy || loaded?.isRefreshing == true
                              ? null
                              : () => context.read<WorkspaceCubit>().load(
                                  force: true,
                                ),
                          child: Text(
                            loaded?.isRefreshing == true
                                ? tr(context, 'Обновляем…')
                                : state is WorkspaceFailure
                                ? tr(context, 'Повторить')
                                : tr(context, 'Обновить список'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}

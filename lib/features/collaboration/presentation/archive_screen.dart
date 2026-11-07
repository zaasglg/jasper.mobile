import '../../../core/widgets/app_dialog.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/widgets/app_action_menu.dart';
import '../data/collaboration_models.dart';
import '../domain/collaboration_repository.dart';

class ArchiveState extends Equatable {
  const ArchiveState({
    this.items = const [],
    this.loading = true,
    this.busyId,
    this.error,
  });
  final List<ManagedSpace> items;
  final bool loading;
  final String? busyId;
  final String? error;
  @override
  List<Object?> get props => [items, loading, busyId, error];
}

class ArchiveCubit extends Cubit<ArchiveState> {
  ArchiveCubit(this.repository, this.kind, this.workspaceId)
    : super(const ArchiveState());
  final CollaborationRepository repository;
  final SpaceKind kind;
  final String? workspaceId;
  Future<void> load() async {
    emit(ArchiveState(items: state.items));
    try {
      final items = await repository.archived(kind, workspaceId: workspaceId);
      if (!isClosed) emit(ArchiveState(items: items, loading: false));
    } catch (e) {
      if (!isClosed) {
        emit(
          ArchiveState(items: state.items, loading: false, error: e.toString()),
        );
      }
    }
  }

  Future<void> act(String id, bool remove) async {
    if (state.busyId != null) return;
    emit(ArchiveState(items: state.items, loading: false, busyId: id));
    try {
      if (remove) {
        await repository.delete(kind, id);
      } else {
        await repository.restore(kind, id);
      }
      if (!isClosed) {
        emit(
          ArchiveState(
            items: state.items.where((e) => e.id != id).toList(),
            loading: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          ArchiveState(items: state.items, loading: false, error: e.toString()),
        );
      }
    }
  }
}

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({required this.kind, this.workspaceId, super.key});
  final SpaceKind kind;
  final String? workspaceId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        ArchiveCubit(sl<CollaborationRepository>(), kind, workspaceId)..load(),
    child: BlocConsumer<ArchiveCubit, ArchiveState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            kind == SpaceKind.project ? 'Архив проектов' : 'Архив workspace',
          ),
        ),
        body: state.loading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: context.read<ArchiveCubit>().load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            state.error == null
                                ? 'Архив пуст'
                                : 'Не удалось загрузить архив',
                          ),
                        ),
                      ),
                    if (state.error != null)
                      TextButton(
                        onPressed: context.read<ArchiveCubit>().load,
                        child: const Text('Повторить'),
                      ),
                    for (final item in state.items)
                      ListTile(
                        leading: const Icon(
                          LucideIcons.archive,
                          size: AppIconSizes.standard,
                        ),
                        title: Text(item.name),
                        trailing: state.busyId == item.id
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : AppActionMenuButton<String>(
                                title: item.name,
                                groups: const [
                                  [
                                    AppMenuAction(
                                      value: 'restore',
                                      label: 'Восстановить',
                                      icon: LucideIcons.archiveRestore,
                                    ),
                                  ],
                                  [
                                    AppMenuAction(
                                      value: 'delete',
                                      label: 'Удалить навсегда',
                                      icon: LucideIcons.trash2,
                                      destructive: true,
                                    ),
                                  ],
                                ],
                                onSelected: (value) async {
                                  if (value == 'delete' &&
                                      !await showAppConfirmation(
                                        context,
                                        'Удалить навсегда?',
                                        'Это действие нельзя отменить.',
                                        confirmLabel: 'Удалить',
                                        destructive: true,
                                      )) {
                                    return;
                                  }
                                  if (context.mounted) {
                                    await context.read<ArchiveCubit>().act(
                                      item.id,
                                      value == 'delete',
                                    );
                                  }
                                },
                              ),
                      ),
                  ],
                ),
              ),
      ),
    ),
  );
}

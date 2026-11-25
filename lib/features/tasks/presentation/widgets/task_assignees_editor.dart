import 'package:jospar/core/localization/app_translations.dart';
import '../../../projects/domain/entities/task_assignee_model.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/repositories/task_details_repository.dart';
import '../cubit/task_details_cubit.dart';

class TaskAssigneesEditor extends StatefulWidget {
  const TaskAssigneesEditor({super.key, required this.cubit});
  final TaskDetailsCubit cubit;
  @override
  State<TaskAssigneesEditor> createState() => _TaskAssigneesEditorState();
}

class _TaskAssigneesEditorState extends State<TaskAssigneesEditor> {
  final _search = TextEditingController();
  late final Set<String> _selected;
  List<TaskAssigneeModel> _users = [];
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _users = widget.cubit.state.task?.assignees ?? [];
    _selected = _users.map((user) => user.userId).toSet();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final candidates = await widget.cubit.getAssigneeCandidates();
      if (!mounted) return;
      setState(() {
        _users = {
          for (final user in [..._users, ...candidates]) user.userId: user,
        }.values.toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is TaskDetailsException
              ? error.message
              : 'Не удалось загрузить исполнителей.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.cubit.updateAssignees(
      _users.where((user) => _selected.contains(user.userId)).toList(),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.cubit.state.actionErrorMessage ??
            'Не удалось сохранить исполнителей.';
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _users
        .where((user) => user.name.toLowerCase().contains(query))
        .toList();
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.58).clamp(
                0.0,
                constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'Исполнители'),
                          style: AppTypography.title(context),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Закрыть выбор исполнителей'),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          size: AppIconSizes.standard,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _search,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Поиск по имени'),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: AppIconSizes.standard,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr(context, 'Очистить поиск'),
                              onPressed: _saving
                                  ? null
                                  : () => setState(_search.clear),
                              icon: const Icon(
                                Icons.close,
                                size: AppIconSizes.standard,
                              ),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, "Выбрано: {p0}", {
                            'p0': _selected.length,
                          }),
                          style: AppTypography.caption(context)?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving || _loading || _selected.isEmpty
                            ? null
                            : () => setState(_selected.clear),
                        child: Text(tr(context, 'Снять всех')),
                      ),
                    ],
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  if (_error != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, _error!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _load,
                          child: Text(tr(context, 'Повторить')),
                        ),
                      ],
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : visible.isEmpty
                        ? Center(
                            child: Text(tr(context, 'Участники не найдены')),
                          )
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final user = visible[index];
                              final selected = _selected.contains(user.userId);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xxs,
                                ),
                                child: CheckboxListTile(
                                  key: ValueKey('assignee-${user.userId}'),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  tileColor: selected
                                      ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: .35)
                                      : null,
                                  checkboxShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  value: _selected.contains(user.userId),
                                  title: Text(
                                    user.name.isEmpty
                                        ? tr(context, 'Пользователь')
                                        : user.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(context)
                                        ?.copyWith(
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                  ),
                                  secondary: UserAvatar(
                                    name: user.name,
                                    avatarUrl: user.avatarUrl,
                                    size: AppSpacing.xl + AppSpacing.sm,
                                  ),
                                  onChanged: _saving
                                      ? null
                                      : (checked) => setState(() {
                                          if (checked == true) {
                                            _selected.add(user.userId);
                                          } else {
                                            _selected.remove(user.userId);
                                          }
                                        }),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: AppSpacing.smMd),
                  FilledButton(
                    key: const Key('save-assignees'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSpacing.touchTarget,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: _saving || _loading || _error != null
                        ? null
                        : _save,
                    child: Text(
                      _saving
                          ? tr(context, 'Сохранение…')
                          : tr(context, 'Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import '../../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../projects/data/models/project_task_model.dart';
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Исполнители',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    hintText: 'Поиск по имени',
                    prefixIcon: Icon(Icons.search, size: AppIconSizes.standard),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextButton(
                  onPressed: _saving || _loading
                      ? null
                      : () => setState(_selected.clear),
                  child: const Text('Снять всех'),
                ),
                if (_error != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                      ? const Center(child: Text('Участники не найдены'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final user = visible[index];
                            return CheckboxListTile(
                              value: _selected.contains(user.userId),
                              title: Text(
                                user.name.isEmpty ? 'Пользователь' : user.name,
                              ),
                              secondary: UserAvatar(
                                name: user.name,
                                avatarUrl: user.avatarUrl,
                                size: 32,
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
                            );
                          },
                        ),
                ),
                FilledButton(
                  onPressed: _saving || _loading || _error != null
                      ? null
                      : _save,
                  child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

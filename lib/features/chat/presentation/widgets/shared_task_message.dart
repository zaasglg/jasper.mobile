import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../kanban/presentation/widgets/task_card.dart';
import '../../../projects/data/models/project_task_model.dart';
import '../../../tasks/domain/repositories/task_details_repository.dart';

typedef SharedTaskLink = ({
  String taskId,
  String projectId,
  String title,
  String displayId,
  String before,
  String after,
});

SharedTaskLink? sharedTaskLink(String text, String? taskRef) {
  final markdown = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');
  final plain = RegExp(r'https?://[^\s)]+');
  for (final matches in [markdown.allMatches(text), plain.allMatches(text)]) {
    for (final match in matches) {
      final isMarkdown = match.groupCount == 2;
      final uri = Uri.tryParse(isMarkdown ? match.group(2)! : match.group(0)!);
      if (uri == null || uri.host != 'jospar.me' || uri.path != '/tasks') {
        continue;
      }
      final taskId = uri.queryParameters['taskId'];
      if (taskId == null || taskId.trim().isEmpty) continue;
      final label = isMarkdown ? match.group(1)! : '';
      final separator = label.indexOf(':');
      return (
        taskId: taskId,
        projectId: uri.queryParameters['project'] ?? '',
        displayId: separator > 0 ? label.substring(0, separator).trim() : '',
        title: separator > 0 ? label.substring(separator + 1).trim() : label,
        before: text.substring(0, match.start),
        after: text.substring(match.end),
      );
    }
  }
  if (taskRef != null && RegExp(r'^[\w-]+$').hasMatch(taskRef)) {
    return (
      taskId: taskRef,
      projectId: '',
      title: text,
      displayId: '',
      before: '',
      after: '',
    );
  }
  return null;
}

class SharedTaskMessage extends StatefulWidget {
  const SharedTaskMessage({
    super.key,
    required this.taskId,
    required this.title,
    required this.displayId,
    required this.projectId,
  });
  final String taskId;
  final String title;
  final String displayId;
  final String projectId;

  @override
  State<SharedTaskMessage> createState() => _SharedTaskMessageState();
}

class _SharedTaskMessageState extends State<SharedTaskMessage> {
  ProjectTaskModel? _task;
  bool _loading = false;
  bool _failed = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SharedTaskMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _task = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (!sl.isRegistered<TaskDetailsRepository>()) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final payload = await sl<TaskDetailsRepository>().getTask(widget.taskId);
      if (!mounted || revision != _revision) return;
      setState(() {
        _task = payload.task;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TaskCard(
        key: Key('shared-task-${widget.taskId}'),
        task:
            _task ??
            ProjectTaskModel(
              id: widget.taskId,
              projectId: widget.projectId,
              status: '',
              displayId: widget.displayId,
              title: widget.title.isEmpty ? 'Задача' : widget.title,
            ),
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: LinearProgressIndicator(minHeight: 2, color: AppColors.accent),
        ),
      if (_failed)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Не удалось обновить задачу',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: _load,
                child: const Text('Повторить', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
    ],
  );
}

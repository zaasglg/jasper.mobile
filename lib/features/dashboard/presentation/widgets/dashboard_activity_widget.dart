import '../../../../core/widgets/app_widget_heading.dart';
import 'dashboard_selector.dart';
import 'dashboard_widget_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/html_text.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'dashboard_widget_panel.dart' show dashboardObject;

class DashboardActivityWidget extends StatefulWidget {
  const DashboardActivityWidget({
    super.key,
    required this.entries,
    required this.loadCategory,
    required this.onOpenTask,
    this.trailing,
  });
  final List<Map<String, dynamic>> entries;
  final Future<List<Map<String, dynamic>>> Function(String) loadCategory;
  final Future<void> Function(String) onOpenTask;
  final Widget? trailing;
  @override
  State<DashboardActivityWidget> createState() =>
      _DashboardActivityWidgetState();
}

class _DashboardActivityWidgetState extends State<DashboardActivityWidget> {
  static const categories = {
    'all': 'Все',
    'tasks': 'Задачи',
    'projects': 'Проекты',
    'team': 'Команда',
    'personal': 'Личное',
  };
  String _category = 'all';
  Future<List<Map<String, dynamic>>>? _future;
  @override
  void didUpdateWidget(covariant DashboardActivityWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries && _category != 'all') {
      _future = widget.loadCategory(_category);
    }
  }

  void _select(String category) => setState(() {
    _category = category;
    _future = category == 'all' ? null : widget.loadCategory(category);
  });
  String _time(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${days == 0
        ? 'Сегодня'
        : days == 1
        ? 'Вчера'
        : '${date.day}.${date.month.toString().padLeft(2, '0')}'}, $time';
  }

  ({String label, IconData icon, Color color}) _style(String type) =>
      switch (type) {
        'TASK_CREATED' => (
          label: 'Создана задача',
          icon: LucideIcons.plus,
          color: AppColors.accent,
        ),
        'TASK_UPDATED' => (
          label: 'Задача обновлена',
          icon: LucideIcons.pencil,
          color: AppColors.accent,
        ),
        'TASK_DELETED' => (
          label: 'Задача удалена',
          icon: LucideIcons.trash2,
          color: const Color(0xFFB52B1D),
        ),
        'TASK_STATUS_CHANGED' => (
          label: 'Перемещение',
          icon: LucideIcons.arrowRightLeft,
          color: const Color(0xFF3B82C4),
        ),
        'TASK_COMPLETED' => (
          label: 'Выполнено',
          icon: LucideIcons.check,
          color: const Color(0xFF1A7048),
        ),
        'COMMENT_ADDED' => (
          label: 'Комментарий',
          icon: LucideIcons.messageSquare,
          color: AppColors.muted,
        ),
        'PROJECT_CREATED' => (
          label: 'Проект создан',
          icon: LucideIcons.folderPlus,
          color: const Color(0xFFA06830),
        ),
        'PROJECT_UPDATED' => (
          label: 'Проект обновлён',
          icon: LucideIcons.folderPen,
          color: const Color(0xFFA06830),
        ),
        'EPIC_CREATED' => (
          label: 'Эпик создан',
          icon: LucideIcons.layers,
          color: const Color(0xFF3B82C4),
        ),
        'USER_JOINED' => (
          label: 'Новый участник',
          icon: LucideIcons.userPlus,
          color: const Color(0xFF1A7060),
        ),
        'USER_LOGIN' => (
          label: 'Вход в систему',
          icon: LucideIcons.logIn,
          color: AppColors.muted,
        ),
        'MENTION' => (
          label: 'Упоминание',
          icon: LucideIcons.atSign,
          color: AppColors.accent,
        ),
        'DM_MESSAGE' => (
          label: 'Личное сообщение',
          icon: LucideIcons.messageCircle,
          color: AppColors.accent,
        ),
        'EMAIL' => (
          label: 'Email',
          icon: LucideIcons.mail,
          color: const Color(0xFF3B82C4),
        ),
        _ => (label: 'Событие', icon: LucideIcons.dot, color: AppColors.muted),
      };
  Widget _entry(Map<String, dynamic> entry) {
    final type = entry['type']?.toString().toUpperCase() ?? '';
    final style = _style(type);
    final user = dashboardObject(entry['user']);
    final meta = dashboardObject(entry['metadata']);
    final taskId =
        (meta['taskId'] ??
                entry['taskId'] ??
                (entry['entityType'] == 'task' ? entry['entityId'] : null))
            ?.toString();
    final projectId = meta['projectId']?.toString();
    final threadId = (meta['threadId'] ?? entry['threadId'])?.toString();
    final name = user['name']?.toString() ?? '';
    var text = htmlToPlainText(
      (entry['description'] ?? entry['text'] ?? entry['action'] ?? '')
          .toString(),
    );
    if (name.isNotEmpty && text.startsWith('$name ')) {
      text = text.substring(name.length).trimLeft();
    }
    final displayId = meta['displayId']?.toString() ?? '';
    final VoidCallback? onTap = type == 'USER_LOGIN'
        ? null
        : taskId != null && type != 'TASK_DELETED'
        ? () => widget.onOpenTask(taskId)
        : projectId != null
        ? () => context.push('/projects/${Uri.encodeComponent(projectId)}')
        : threadId != null
        ? () => context.push('/messenger/${Uri.encodeComponent(threadId)}')
        : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(style.icon, size: 16, color: style.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            style.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: style.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _time(entry['createdAt']),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (name.isNotEmpty)
                          TextSpan(
                            text: '$name ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF252537),
                            ),
                          ),
                        TextSpan(
                          text: text.isEmpty
                              ? 'Событие рабочего пространства'
                              : text,
                        ),
                        if (displayId.isNotEmpty)
                          TextSpan(
                            text: ' $displayId',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF72728A),
                      height: 1.45,
                    ),
                  ),
                  if (user.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          UserAvatar(
                            size: 16,
                            userId: user['id']?.toString(),
                            name: name,
                            avatarUrl:
                                (user['avatarUrl'] ?? user['avatar'])
                                    as String?,
                            backgroundColor: AppColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entries(List<Map<String, dynamic>> entries) {
    final visible = entries.take(6).toList();
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'Нет событий',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _entry(visible[i]),
          if (i + 1 < visible.length)
            const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: AppWidgetHeading(
              icon: LucideIcons.clock,
              title: 'Последняя активность',
            ),
          ),
          DashboardSelector<String>(
            tooltip: 'Категория активности',
            onSelected: _select,
            itemBuilder: (_) => [
              for (final entry in categories.entries)
                CheckedPopupMenuItem(
                  value: entry.key,
                  checked: _category == entry.key,
                  child: Text(entry.value),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    categories[_category]!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 14,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          ?widget.trailing,
        ],
      ),
      const SizedBox(height: 6),
      if (_category == 'all')
        _entries(widget.entries)
      else
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const DashboardWidgetSkeleton(showHeading: false);
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Не удалось загрузить активность',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _select(_category),
                    child: const Text('Повторить'),
                  ),
                ],
              );
            }
            return _entries(snapshot.data ?? []);
          },
        ),
    ],
  );
}

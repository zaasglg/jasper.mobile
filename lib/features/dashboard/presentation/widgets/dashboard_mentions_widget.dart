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

class DashboardMentionsWidget extends StatefulWidget {
  const DashboardMentionsWidget({
    super.key,
    required this.entries,
    required this.onOpenTask,
    this.loadRead,
    this.saveRead,
    this.trailing,
  });
  final List<Map<String, dynamic>> entries;
  final Future<void> Function(String) onOpenTask;
  final Future<Set<String>> Function()? loadRead;
  final Future<void> Function(Set<String>)? saveRead;
  final Widget? trailing;
  @override
  State<DashboardMentionsWidget> createState() =>
      _DashboardMentionsWidgetState();
}

class _DashboardMentionsWidgetState extends State<DashboardMentionsWidget> {
  static const sources = {
    'all': 'Все источники',
    'messenger': 'Мессенджер',
    'task': 'Проекты',
  };
  String _source = 'all';
  Set<String> _read = {};
  bool _loading = false, _saving = false;
  @override
  void initState() {
    super.initState();
    if (widget.loadRead != null) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    Set<String> saved = {};
    try {
      saved = await widget.loadRead!();
    } catch (_) {
      /* Keep the feed usable if local storage is unavailable. */
    }
    if (mounted) {
      setState(() {
        _read = {...saved, ..._read};
        _loading = false;
      });
    }
  }

  String _id(Map<String, dynamic> e) =>
      e['feedId']?.toString() ?? '${e['feedKind'] ?? 'mention'}:${e['id']}';
  String _entrySource(Map<String, dynamic> e) => e['feedKind'] == 'reaction'
      ? 'messenger'
      : e['source'] == 'task' || e['taskId'] != null
      ? 'task'
      : 'messenger';
  List<Map<String, dynamic>> get _filtered =>
      widget.entries
          .where((e) => _source == 'all' || _entrySource(e) == _source)
          .toList()
        ..sort(
          (a, b) =>
              (DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                      DateTime(1970))
                  .compareTo(
                    DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                        DateTime(1970),
                  ),
        );
  Future<void> _mark(Set<String> ids) async {
    if (_saving || ids.isEmpty) return;
    final previous = _read;
    final next = {..._read, ...ids};
    setState(() {
      _read = next;
      _saving = true;
    });
    try {
      await widget.saveRead?.call(next);
    } catch (_) {
      if (mounted) {
        setState(() => _read = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить отметку о прочтении'),
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _open(Map<String, dynamic> entry) async {
    await _mark({_id(entry)});
    if (!mounted) return;
    final message = dashboardObject(entry['message']);
    final taskId =
        entry['taskId'] ??
        (entry['entityType'] == 'task' ? entry['entityId'] : null);
    final threadId = entry['threadId'] ?? message['threadId'];
    if (taskId != null) {
      await widget.onOpenTask(taskId.toString());
    } else if (threadId != null) {
      final messageId =
          message['id'] ??
          (entry['feedKind'] == 'reaction' ? entry['messageId'] : entry['id']);
      final suffix = messageId == null
          ? ''
          : '?messageId=${Uri.encodeQueryComponent(messageId.toString())}';
      await context.push(
        '/messenger/${Uri.encodeComponent(threadId.toString())}$suffix',
      );
    } else {
      await context.push('/activity/mentions');
    }
  }

  TextSpan _message(String text) {
    final matches = RegExp(r'@\[([^\]]+)\]').allMatches(text);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in matches) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: '@${match.group(1)}',
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return TextSpan(children: spans);
  }

  Widget _entry(Map<String, dynamic> entry) {
    final user = dashboardObject(entry['user']),
        message = dashboardObject(entry['message']);
    final reaction = entry['feedKind'] == 'reaction';
    final source = _entrySource(entry);
    final name = user['name']?.toString() ?? 'Участник';
    final body = htmlToPlainText(
      (entry['text'] ?? entry['description'] ?? message['text'] ?? '')
          .toString(),
    );
    final text = reaction
        ? '${entry['emoji'] ?? ''} отреагировал(а) на «${body.isEmpty ? 'сообщение' : body}»'
        : body;
    final time = DateTime.tryParse(
      entry['createdAt']?.toString() ?? '',
    )?.toLocal();
    final date = time == null ? '' : time.toIso8601String().substring(0, 10);
    final contextLabel = source == 'task'
        ? entry['projectName']?.toString()
        : dashboardObject(
                entry['channel'] ?? message['channel'],
              )['name']?.toString() ??
              entry['channelName']?.toString();
    return InkWell(
      onTap: _saving ? null : () => _open(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              size: 26,
              userId: user['id']?.toString(),
              name: name,
              avatarUrl: (user['avatarUrl'] ?? user['avatar']) as String?,
              backgroundColor: const Color(0xFFF1EFFB),
              foregroundColor: AppColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    _message(text.isEmpty ? 'Упоминание' : text),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF484854),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          '· $date',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      Icon(
                        source == 'task'
                            ? LucideIcons.squareCheck
                            : LucideIcons.messageCircle,
                        size: 11,
                        color: AppColors.muted,
                      ),
                      if (contextLabel != null)
                        Text(
                          contextLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _filtered.where((e) => !_read.contains(_id(e))).toList();
    final visible = unread.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppWidgetHeading(
                icon: LucideIcons.atSign,
                title: 'Упоминания',
              ),
            ),
            DashboardSelector<String>(
              tooltip: 'Источник упоминаний',
              onSelected: (source) => setState(() => _source = source),
              itemBuilder: (_) => [
                for (final item in sources.entries)
                  CheckedPopupMenuItem(
                    value: item.key,
                    checked: _source == item.key,
                    child: Text(item.value),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sources[_source]!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                    if (unread.isNotEmpty && !_loading) ...[
                      const SizedBox(width: 5),
                      Text(
                        '${unread.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.chevronDown,
                      size: 13,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Прочитать всё в выбранных фильтрах',
              onPressed: _loading || _saving || unread.isEmpty
                  ? null
                  : () => _mark(_filtered.map(_id).toSet()),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(5),
                minimumSize: const Size(28, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                LucideIcons.checkCheck,
                size: 15,
                color: AppColors.muted,
              ),
            ),
            ?widget.trailing,
          ],
        ),
        if (_loading)
          const DashboardWidgetSkeleton(showHeading: false)
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Нет упоминаний',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            _entry(visible[i]),
            if (i + 1 < visible.length)
              const Divider(height: 1, color: AppColors.border),
          ],
      ],
    );
  }
}

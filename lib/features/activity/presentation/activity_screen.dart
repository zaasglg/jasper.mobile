import 'package:jospar/core/localization/app_translations.dart';
import 'mention_activity_tile.dart';
import '../../../core/widgets/app_snack_bar.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/domain/repositories/chat_repository.dart';
import '../data/activity_repository.dart';

class ActivityState extends Equatable {
  const ActivityState({this.items = const [], this.loading = true, this.error});
  final List<ActivityEntry> items;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [items, loading, error];
}

class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit(this.repository, this.kind) : super(const ActivityState());
  final ActivityRepository repository;
  final ActivityKind kind;
  Future<void> load() async {
    if (isClosed) return;
    emit(ActivityState(items: state.items));
    try {
      final items = await repository.load(kind);
      if (!isClosed) emit(ActivityState(items: items, loading: false));
    } catch (_) {
      if (!isClosed) {
        emit(
          ActivityState(
            items: state.items,
            loading: false,
            error: 'Не удалось загрузить данные. Повторите попытку.',
          ),
        );
      }
    }
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.kind, super.key});
  final ActivityKind kind;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ActivityCubit(sl<ActivityRepository>(), kind)..load(),
    child: _ActivityBody(kind: kind),
  );
}

class _ActivityBody extends StatefulWidget {
  const _ActivityBody({required this.kind});
  final ActivityKind kind;
  @override
  State<_ActivityBody> createState() => _ActivityBodyState();
}

class _ActivityBodyState extends State<_ActivityBody> {
  bool _leaving = false;
  ActivityKind get kind => widget.kind;

  void _back() {
    if (_leaving) return;
    _leaving = true;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/messenger');
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ActivityCubit, ActivityState>(
    builder: (context, state) => Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        centerTitle: kind == ActivityKind.mentions ? false : null,
        titleTextStyle: kind == ActivityKind.mentions
            ? Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )
            : null,
        title: Text(switch (kind) {
          ActivityKind.notifications => tr(context, 'Уведомления'),
          ActivityKind.mentions => tr(context, 'Упоминания и реакции'),
          ActivityKind.discussions => tr(context, 'Обсуждения'),
          ActivityKind.saved => tr(context, 'Сохранённое'),
        }),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<ActivityCubit>().load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kind == ActivityKind.notifications
              ? const EdgeInsets.only(bottom: 24)
              : const EdgeInsets.all(16),
          children: [
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            if (state.error != null)
              TextButton(
                onPressed: context.read<ActivityCubit>().load,
                child: Text(tr(context, state.error!)),
              ),
            if (!state.loading && state.error == null && state.items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.bell,
                      size: 32,
                      color: AppColors.of(context).muted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      kind == ActivityKind.notifications
                          ? tr(context, 'Новых уведомлений пока нет')
                          : tr(context, 'Пока ничего нет'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (kind == ActivityKind.notifications && state.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Text(
                  tr(context, 'Последние события'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ),
            for (final entry in state.items)
              if (kind == ActivityKind.notifications)
                _NotificationTile(
                  entry: entry,
                  onTap: () => _open(context, entry),
                )
              else if (kind == ActivityKind.mentions)
                MentionActivityTile(
                  entry: entry,
                  onTap: () => _open(context, entry),
                )
              else
                ListTile(
                  leading: Icon(
                    kind == ActivityKind.saved
                        ? LucideIcons.bookmark
                        : LucideIcons.messageSquare,
                    size: AppIconSizes.standard,
                  ),
                  title: Text(
                    entry.title.isEmpty
                        ? (entry.taskId == null ? 'Сообщение' : 'Задача')
                        : entry.title,
                  ),
                  subtitle: Text(
                    entry.text.isEmpty ? tr(context, 'Вложение') : entry.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(context, entry),
                ),
          ],
        ),
      ),
    ),
  );
  Future<void> _open(BuildContext context, ActivityEntry entry) async {
    if (entry.taskId != null) {
      await context.push('/tasks/${entry.taskId}');
      return;
    }
    if (entry.threadId == null) return;
    try {
      final chats = await sl<ChatRepository>().getConversations();
      final matches = chats.where(
        (chat) => chat.threadId == entry.threadId || chat.id == entry.threadId,
      );
      if (!context.mounted) return;
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.info,
            content: Text(tr(context, 'Обсуждение больше недоступно.')),
          ),
        );
        return;
      }
      final chat = matches.first;
      await context.push(
        '/messenger/${Uri.encodeComponent(chat.id)}',
        extra: chat,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(tr(context, 'Не удалось открыть обсуждение.')),
          ),
        );
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.entry, required this.onTap});
  final ActivityEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reaction = entry.id.startsWith('reaction:');
    final mention = entry.id.startsWith('mention:');
    final parts = entry.title.split(' · ');
    final hasEmoji = parts.first.runes.any(
      (rune) => rune >= 0x1F000 || (rune >= 0x2600 && rune <= 0x27BF),
    );
    final emoji = reaction && parts.length > 1 && hasEmoji ? parts.first : null;
    final author = emoji == null ? entry.title : parts.skip(1).join(' · ');
    final label = reaction
        ? 'Реакция на сообщение'
        : mention
        ? 'Упомянули вас'
        : 'Новое сообщение';
    final date = entry.createdAt?.toLocal();
    final now = DateTime.now();
    final sameDay =
        date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    String two(int value) => value.toString().padLeft(2, '0');
    final time = date == null
        ? null
        : sameDay
        ? '${two(date.hour)}:${two(date.minute)}'
        : '${two(date.day)}.${two(date.month)}.${date.year}';
    final canOpen = entry.taskId != null || entry.threadId != null;
    return Material(
      color: AppColors.of(context).canvas,
      child: InkWell(
        onTap: canOpen ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.of(context).border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: emoji != null
                      ? ExcludeSemantics(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        )
                      : Icon(
                          mention
                              ? LucideIcons.atSign
                              : LucideIcons.messageSquare,
                          size: 20,
                          color: AppColors.accent,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.of(context).muted,
                            ),
                          ),
                          if (time != null)
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.of(context).muted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author.isEmpty ? tr(context, 'Сообщение') : author,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.text.isEmpty
                            ? tr(context, 'Вложение')
                            : entry.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canOpen) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: AppColors.of(context).muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../chat/presentation/widgets/reaction_emoji.dart';
import '../data/activity_repository.dart';

class MentionActivityTile extends StatelessWidget {
  const MentionActivityTile({
    super.key,
    required this.entry,
    required this.onTap,
  });
  final ActivityEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kk = Localizations.localeOf(context).languageCode == 'kk';
    final reaction = entry.id.startsWith('reaction:');
    final parts = entry.title.split(' · ');
    final emoji = reaction && parts.length > 1 ? parts.removeAt(0) : null;
    final author = parts.first.isEmpty
        ? (kk ? 'Пайдаланушы' : 'Пользователь')
        : parts.first;
    final channel = parts.length > 1 ? parts.skip(1).join(' · ') : null;
    final quote = RegExp(
      r'^↩ @(.+?): «([\s\S]*?)»\n\n([\s\S]*)$',
    ).firstMatch(entry.text);
    final body = quote?[3] ?? entry.text;
    final date = entry.createdAt?.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = date != null && DateUtils.isSameDay(date, now);
    final time = date == null
        ? null
        : today
        ? '${two(date.hour)}:${two(date.minute)}'
        : '${two(date.day)}.${two(date.month)} · ${two(date.hour)}:${two(date.minute)}';
    final canOpen = entry.threadId != null || entry.taskId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: ValueKey('mention-activity-${entry.id}'),
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .45),
            width: .75,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      size: 42,
                      userId: entry.authorId,
                      name: author,
                      avatarUrl: entry.avatarUrl,
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: emoji == null
                            ? const Icon(
                                LucideIcons.atSign,
                                size: 15,
                                color: AppColors.accent,
                              )
                            : ReactionEmoji(emoji, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reaction
                            ? (kk
                                  ? 'Хабарламаңызға реакция қалдырды'
                                  : 'Реакция на ваше сообщение')
                            : (kk ? 'Сізді атап өтті' : 'Вас упомянули'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: .035),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: AppColors.accent.withValues(alpha: .5),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (quote != null) ...[
                              Text(
                                '${quote[1]}: ${quote[2]}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              body.isEmpty
                                  ? (kk ? 'Тіркеме' : 'Вложение')
                                  : body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (channel != null || time != null) ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            if (channel != null)
                              Expanded(
                                child: Text(
                                  channel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            if (time != null)
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

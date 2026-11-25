import 'package:jospar/core/localization/app_translations.dart';
import 'reaction_emoji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_message_model.dart';
import 'forward_message_sheet.dart';
import '../cubit/conversation_cubit.dart';

Future<void> showMessageReactions(
  BuildContext context,
  ChatMessageModel message,
) async {
  final cubit = context.read<ConversationCubit>();
  final emoji = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, 'Выберите реакцию'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 60,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (final value in [
                    '👍',
                    '❤️',
                    '😂',
                    '😮',
                    '😢',
                    '🙏',
                    '🔥',
                    '✅',
                    '🎉',
                    '😍',
                    '👏',
                    '😁',
                    '🤔',
                    '💯',
                    '🤝',
                    '👀',
                    '🙌',
                    '💜',
                    '💪',
                    '🥰',
                    '🤗',
                    '😎',
                    '🤩',
                    '👌',
                  ])
                    Semantics(
                      button: true,
                      label: value,
                      child: InkWell(
                        key: ValueKey('reaction-picker-$value'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, value),
                        child: Center(child: ReactionEmoji(value, size: 38)),
                      ),
                    ),
                ],
              ),
            ),
            TextField(
              maxLength: 16,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: tr(context, 'Другой эмодзи'),
                counterText: '',
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (emoji != null && !cubit.isClosed) {
    await cubit.interact(message.id, emoji: emoji);
  }
}

Future<void> showForwardMessage(
  BuildContext context,
  ChatMessageModel message,
) {
  final cubit = context.read<ConversationCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => ForwardMessageSheet(cubit: cubit, message: message),
  );
}

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({super.key, required this.message});
  final ChatMessageModel message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reactions = message.reactions.where((r) => r.count > 0).toList();
    if (reactions.isEmpty) return const SizedBox.shrink();
    final count = reactions.fold<int>(
      0,
      (sum, reaction) => sum + reaction.count,
    );
    return Material(
      key: ValueKey('message-reactions-${message.id}'),
      color: colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: dark ? .5 : .35),
          width: .75,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24 + (reactions.length - 1) * 18.0,
              height: 24,
              child: Stack(
                children: [
                  for (var i = 0; i < reactions.length; i++)
                    Positioned(
                      left: i * 18.0,
                      top: 0,
                      child: Tooltip(
                        message: reactions[i].authors.join(', '),
                        child: Semantics(
                          label: '${reactions[i].emoji} ${reactions[i].count}',
                          button: true,
                          selected: reactions[i].reacted,
                          child: InkWell(
                            key: ValueKey(
                              'reaction-chip-${message.id}-${reactions[i].emoji}',
                            ),
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                context.read<ConversationCubit>().interact(
                                  message.id,
                                  emoji: reactions[i].emoji,
                                ),
                            child: SizedBox.square(
                              dimension: 24,
                              child: Center(
                                child: ReactionEmoji(
                                  reactions[i].emoji,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  count > 999 ? '999+' : '$count',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PinnedMessagesBar extends StatelessWidget {
  const PinnedMessagesBar({
    super.key,
    required this.messages,
    required this.onSelect,
  });
  final List<ChatMessageModel> messages;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    final pinned = messages.where((m) => m.pinned).toList();
    if (pinned.isEmpty) return const SizedBox();
    return Material(
      color: AppColors.of(context).canvas,
      child: InkWell(
        onTap: () async {
          if (pinned.length == 1) {
            onSelect(pinned.single.id);
            return;
          }
          final id = await showAppDialog<String>(
            context: context,
            builder: (context) => AppDialog(
              title: Text(tr(context, 'Закреплённые сообщения')),
              content: SizedBox(
                width: double.maxFinite,
                height: 280,
                child: ListView(
                  children: [
                    for (final m in pinned)
                      ListTile(
                        title: Text(m.authorName),
                        subtitle: Text(
                          m.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, m.id),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Закрыть')),
                ),
              ],
            ),
          );
          if (id != null) onSelect(id);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.of(context).border),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 12,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tr(context, 'Закреплённые'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).outgoingMessage,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${pinned.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pinned.last.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.of(context).ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.of(context).muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

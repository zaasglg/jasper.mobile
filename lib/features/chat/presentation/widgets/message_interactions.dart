import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/chat_conversation_model.dart';
import '../cubit/conversation_cubit.dart';

Future<void> showMessageReactions(
  BuildContext context,
  ChatMessageModel message,
) async {
  final cubit = context.read<ConversationCubit>();
  final emoji = await showAppDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: const Text('Реакция'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final emoji in [
                '👍',
                '❤️',
                '😂',
                '😮',
                '😢',
                '🔥',
                '✅',
                '🎉',
              ])
                TextButton(
                  onPressed: () => Navigator.pop(context, emoji),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            maxLength: 16,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Другой эмодзи',
              counterText: '',
            ),
            onSubmitted: (value) {
              final emoji = value.trim();
              if (emoji.isNotEmpty) Navigator.pop(context, emoji);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
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
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ForwardDialog(cubit: cubit, message: message),
  );
}

class _ForwardDialog extends StatefulWidget {
  const _ForwardDialog({required this.cubit, required this.message});
  final ConversationCubit cubit;
  final ChatMessageModel message;
  @override
  State<_ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<_ForwardDialog> {
  late Future<List<ChatConversationModel>> _targets;
  String _query = '';
  String? _error, _sending;
  @override
  void initState() {
    super.initState();
    _targets = widget.cubit.forwardTargets();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _sending == null,
    child: AppDialog(
      title: const Text('Переслать сообщение'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFormSurface(
            child: TextField(
              enabled: _sending == null,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Найти чат',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            width: double.maxFinite,
            child: FutureBuilder<List<ChatConversationModel>>(
              future: _targets,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(
                        () => _targets = widget.cubit.forwardTargets(),
                      ),
                      child: const Text('Повторить загрузку чатов'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final targets = snapshot.data!
                    .where(
                      (e) =>
                          e.title.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();
                if (targets.isEmpty) {
                  return const Center(child: Text('Чаты не найдены'));
                }
                return ListView(
                  children: [
                    for (final target in targets)
                      ListTile(
                        leading: Icon(
                          target.isChannel ? Icons.tag : Icons.person_outline,
                          size: 20,
                        ),
                        title: Text(target.title),
                        trailing: _sending == target.id
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        enabled: _sending == null,
                        onTap: () async {
                          setState(() {
                            _sending = target.id;
                            _error = null;
                          });
                          final success = await widget.cubit.forward(
                            widget.message,
                            target,
                          );
                          if (!context.mounted) return;
                          if (success) {
                            Navigator.pop(context);
                          } else {
                            setState(() {
                              _sending = null;
                              _error =
                                  widget.cubit.state.error ??
                                  'Не удалось переслать сообщение';
                            });
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending == null ? () => Navigator.pop(context) : null,
          child: const Text('Отмена'),
        ),
      ],
    ),
  );
}

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({super.key, required this.message});
  final ChatMessageModel message;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    runSpacing: 4,
    children: [
      for (final reaction in message.reactions)
        Tooltip(
          message: reaction.authors.join(', '),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.read<ConversationCubit>().interact(
              message.id,
              emoji: reaction.emoji,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: reaction.reacted
                    ? AppColors.accent.withValues(alpha: .12)
                    : const Color(0xfff3f3f6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: reaction.reacted
                      ? AppColors.accent.withValues(alpha: .4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                '${reaction.emoji} ${reaction.count}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
    ],
  );
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
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.push_pin_outlined,
        size: 18,
        color: AppColors.accent,
      ),
      title: Text(
        'Закреплённые · ${pinned.length}',
        style: const TextStyle(fontSize: 12, color: AppColors.accent),
      ),
      subtitle: Text(
        pinned.last.preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () async {
        if (pinned.length == 1) {
          onSelect(pinned.single.id);
          return;
        }
        final id = await showAppDialog<String>(
          context: context,
          builder: (context) => AppDialog(
            title: const Text('Закреплённые сообщения'),
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
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
        if (id != null) onSelect(id);
      },
    );
  }
}

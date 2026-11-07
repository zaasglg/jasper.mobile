import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../collaboration/data/collaboration_models.dart';
import '../../../storage/data/storage_models.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../domain/repositories/chat_repository.dart';

/// The same management menu is available directly on every conversation row.
class ConversationMenuButton extends StatefulWidget {
  const ConversationMenuButton({
    super.key,
    required this.conversation,
    required this.repository,
    required this.chats,
    required this.onChanged,
    this.onOpen,
  });
  final ChatConversationModel conversation;
  final ChatRepository repository;
  final List<ChatConversationModel> chats;
  final Future<void> Function() onChanged;
  final VoidCallback? onOpen;
  @override
  State<ConversationMenuButton> createState() => _ConversationMenuButtonState();
}

class _ConversationMenuButtonState extends State<ConversationMenuButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => AppActionMenuButton<String>(
    title: widget.conversation.title,
    tooltip: 'Действия: ${widget.conversation.title}',
    enabled: !_busy,
    groups: widget.conversation.isChannel
        ? [
            [
              const AppMenuAction(
                value: 'rename',
                label: 'Переименовать',
                icon: LucideIcons.pencil,
              ),
              const AppMenuAction(
                value: 'members',
                label: 'Участники',
                icon: LucideIcons.users,
              ),
            ],
            [
              const AppMenuAction(
                value: 'leave',
                label: 'Покинуть канал',
                icon: LucideIcons.logOut,
              ),
              const AppMenuAction(
                value: 'delete',
                label: 'Удалить канал',
                icon: LucideIcons.trash2,
                destructive: true,
              ),
            ],
          ]
        : [
            [
              if (widget.onOpen != null)
                const AppMenuAction(
                  value: 'open',
                  label: 'Открыть переписку',
                  icon: LucideIcons.messageCircle,
                ),
              if (widget.repository is ChatInteractionRepository)
                const AppMenuAction(
                  value: 'storage',
                  label: 'Кладовка',
                  icon: LucideIcons.archive,
                ),
            ],
            [
              if (widget.repository is ChatThreadActionsRepository)
                const AppMenuAction(
                  value: 'clear',
                  label: 'Очистить переписку',
                  icon: LucideIcons.eraser,
                  destructive: true,
                ),
            ],
          ],
    onSelected: _action,
  );
  Future<void> _action(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final item = widget.conversation;
    final repository = widget.repository;
    try {
      if (action == 'open') {
        widget.onOpen?.call();
        return;
      }
      if (action == 'storage') {
        final workspace = await (repository as ChatInteractionRepository)
            .interactionWorkspaceId();
        if (!mounted) return;
        await context.push(
          '/storage',
          extra: StorageScope(
            source: StorageSource.chat,
            id: item.threadId,
            workspaceId: workspace,
            title: item.title,
          ),
        );
        return;
      }
      bool changed = false;
      if (action == 'clear') {
        if (await showAppConfirmation(
          context,
          'Очистить переписку?',
          'Старые сообщения будут скрыты только у вас. Собеседник продолжит их видеть.',
          confirmLabel: 'Очистить',
          destructive: true,
        )) {
          if (!mounted) return;
          await (repository as ChatThreadActionsRepository).clearConversation(
            item.threadId,
          );
          changed = true;
        }
      } else {
        if (repository is! ChatActionsRepository) {
          throw const ChatException('Действие недоступно.');
        }
        final actions = repository as ChatActionsRepository;
        if (action == 'rename') {
          final name = await showAppDialog<String>(
            context: context,
            builder: (_) => _ChannelNameDialog(initial: item.title),
          );
          if (!mounted) return;
          if (name != null) {
            await actions.renameChannel(item.id, name);
            changed = true;
          }
        } else if (action == 'members') {
          final members = await actions.channelMembers(item.id);
          if (!mounted) return;
          final ids = await showAppDialog<List<String>>(
            context: context,
            builder: (_) => _ChannelMembersDialog(
              members: members,
              candidates: widget.chats
                  .where((e) => !e.isChannel)
                  .map((e) => SpaceMember(userId: e.id, name: e.title))
                  .toList(),
            ),
          );
          if (!mounted) return;
          if (ids != null) {
            await actions.setChannelMembers(item.id, ids);
            changed = true;
          }
        } else if (await showAppConfirmation(
          context,
          action == 'delete' ? 'Удалить канал?' : 'Покинуть канал?',
          item.title,
          confirmLabel: action == 'delete' ? 'Удалить' : 'Выйти',
          destructive: action == 'delete',
        )) {
          if (!mounted) return;
          if (action == 'delete') {
            await actions.deleteChannel(item.id);
          } else {
            await actions.leaveChannel(item.id);
          }
          changed = true;
        }
      }
      if (changed && mounted) await widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ChatException
                  ? error.message
                  : 'Не удалось выполнить действие. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ChannelNameDialog extends StatefulWidget {
  const _ChannelNameDialog({required this.initial});
  final String initial;
  @override
  State<_ChannelNameDialog> createState() => _ChannelNameDialogState();
}

class _ChannelNameDialogState extends State<_ChannelNameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: const Text('Название канала'),
    content: AppFormSurface(
      child: TextField(
        controller: _text,
        decoration: InputDecoration(errorText: _error),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      TextButton(
        onPressed: () {
          final name = _text.text.trim();
          if (name.isEmpty) {
            setState(() => _error = 'Введите название');
          } else {
            Navigator.pop(context, name);
          }
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}

class _ChannelMembersDialog extends StatefulWidget {
  const _ChannelMembersDialog({
    required this.members,
    required this.candidates,
  });
  final List<SpaceMember> members, candidates;
  @override
  State<_ChannelMembersDialog> createState() => _ChannelMembersDialogState();
}

class _ChannelMembersDialogState extends State<_ChannelMembersDialog> {
  late final _ids = widget.members.map((e) => e.userId).toSet();
  @override
  Widget build(BuildContext context) {
    final people = {
      for (final user in [...widget.candidates, ...widget.members])
        user.userId: user,
    };
    return AppDialog(
      title: const Text('Участники канала'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: ListView(
          children: [
            for (final user in people.values)
              CheckboxListTile(
                title: Text(user.name),
                value: _ids.contains(user.userId),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _ids.add(user.userId);
                  } else {
                    _ids.remove(user.userId);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ids.toList()),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

import 'package:jospar/core/localization/app_translations.dart';
import '../messenger_list_strings.dart';
import '../../data/models/channel_info_model.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../channel_members_strings.dart';
import '../../domain/repositories/channel_image_repository.dart';
import '../channel_photo_strings.dart';
import 'channel_info_sheet.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../collaboration/domain/entities/space_member.dart';
import '../../../storage/domain/entities/storage_scope.dart';
import '../../../storage/domain/entities/storage_enums.dart';
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
  bool _loadingMembers = false;
  @override
  Widget build(BuildContext context) => AppActionMenuButton<String>(
    title: widget.conversation.title,
    tooltip: tr(context, "Действия: {p0}", {'p0': widget.conversation.title}),
    enabled: !_busy,
    groups: widget.conversation.isChannel
        ? [
            [
              if (widget.repository is ChannelImageRepository)
                AppMenuAction(
                  value: 'info',
                  label: ChannelPhotoStrings.of(context).info,
                  icon: LucideIcons.info,
                ),
              AppMenuAction(
                value: 'rename',
                label: tr(context, 'Переименовать'),
                icon: LucideIcons.pencil,
              ),
              AppMenuAction(
                value: 'members',
                label: tr(context, 'Участники'),
                icon: LucideIcons.users,
              ),
            ],
            [
              AppMenuAction(
                value: 'leave',
                label: tr(context, 'Покинуть канал'),
                icon: LucideIcons.logOut,
              ),
              AppMenuAction(
                value: 'delete',
                label: tr(context, 'Удалить канал'),
                icon: LucideIcons.trash2,
                destructive: true,
              ),
            ],
          ]
        : [
            [
              if (widget.onOpen != null)
                AppMenuAction(
                  value: 'open',
                  label: tr(context, 'Открыть переписку'),
                  icon: LucideIcons.messageCircle,
                ),
              if (widget.repository is ChatInteractionRepository)
                AppMenuAction(
                  value: 'storage',
                  label: tr(context, 'Кладовка'),
                  icon: LucideIcons.archive,
                ),
            ],
            [
              if (widget.repository is ChatThreadActionsRepository)
                AppMenuAction(
                  value: 'clear',
                  label: tr(context, 'Очистить переписку'),
                  icon: LucideIcons.eraser,
                  destructive: true,
                ),
              if (widget.repository is ChatThreadActionsRepository)
                AppMenuAction(
                  value: 'delete_chat',
                  label: MessengerListStrings.of(context).deleteChat,
                  icon: LucideIcons.trash2,
                  destructive: true,
                ),
            ],
          ],
    onSelected: _action,
    child: _loadingMembers
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
  );
  Future<void> _action(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final item = widget.conversation;
    final repository = widget.repository;
    try {
      if (action == 'info') {
        await showChannelInfo(
          context,
          item,
          repository as ChannelImageRepository,
        );
        return;
      }
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
      if (action == 'delete_chat') {
        final strings = MessengerListStrings.of(context);
        if (await showAppConfirmation(
          context,
          strings.deleteChatTitle,
          strings.deleteChatDescription,
          confirmLabel: strings.deleteConfirm,
          destructive: true,
        )) {
          if (!mounted) return;
          await (repository as ChatThreadActionsRepository).deleteConversation(
            item.threadId,
          );
          changed = true;
        }
      } else if (action == 'clear') {
        if (await showAppConfirmation(
          context,
          tr(context, 'Очистить переписку?'),
          tr(
            context,
            'Старые сообщения будут скрыты только у вас. Собеседник продолжит их видеть.',
          ),
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
          setState(() => _loadingMembers = true);
          // Membership candidates come from this workspace, not recent chats.
          final results = await Future.wait<Object>([
            repository is ChannelImageRepository
                ? (repository as ChannelImageRepository).channelInfo(item.id)
                : actions
                      .channelMembers(item.id)
                      .then(
                        (members) =>
                            ChannelInfoModel(members: members, canManage: true),
                      ),
            repository is ChannelMembersRepository
                ? (repository as ChannelMembersRepository)
                      .workspaceChannelCandidates()
                : Future.value(
                    widget.chats
                        .where((e) => !e.isChannel)
                        .map(
                          (e) => SpaceMember(
                            userId: e.id,
                            name: e.title,
                            avatarUrl: e.avatarUrl,
                          ),
                        )
                        .toList(),
                  ),
          ]);
          if (mounted) setState(() => _loadingMembers = false);
          final info = results[0] as ChannelInfoModel;
          final candidates = results[1] as List<SpaceMember>;
          if (!mounted) return;
          final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            builder: (_) => _ChannelMembersSheet(
              members: info.members,
              candidates: candidates,
              canManage: info.canManage,
              onSave: (ids) => actions.setChannelMembers(item.id, ids),
            ),
          );
          if (!mounted) return;
          changed = saved == true;
        } else if (await showAppConfirmation(
          context,
          action == 'delete'
              ? tr(context, 'Удалить канал?')
              : tr(context, 'Покинуть канал?'),
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
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(
              error is ChatException
                  ? error.message
                  : tr(
                      context,
                      'Не удалось выполнить действие. Попробуйте ещё раз.',
                    ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loadingMembers = false;
        });
      }
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
    title: Text(tr(context, 'Название канала')),
    content: AppFormSurface(
      child: TextField(
        controller: _text,
        decoration: InputDecoration(errorText: trn(context, _error)),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Отмена')),
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
        child: Text(tr(context, 'Сохранить')),
      ),
    ],
  );
}

class _ChannelMembersSheet extends StatefulWidget {
  const _ChannelMembersSheet({
    required this.members,
    required this.candidates,
    required this.canManage,
    required this.onSave,
  });
  final List<SpaceMember> members, candidates;
  final bool canManage;
  final Future<void> Function(List<String>) onSave;
  @override
  State<_ChannelMembersSheet> createState() => _ChannelMembersSheetState();
}

class _ChannelMembersSheetState extends State<_ChannelMembersSheet> {
  late final _ids = widget.members.map((e) => e.userId).toSet();
  String _query = '';
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving || !widget.canManage) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_ids.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              error is ChatException && !ChannelMembersStrings.of(context).kk
              ? error.message
              : ChannelMembersStrings.of(context).saveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ChannelMembersStrings.of(context);
    final people = <String, SpaceMember>{
      for (final user in widget.candidates) user.userId: user,
    };
    for (final member in widget.members) {
      final candidate = people[member.userId];
      people[member.userId] = member.copyWith(
        avatarUrl: member.avatarUrl ?? candidate?.avatarUrl,
        email: member.email.isNotEmpty ? member.email : candidate?.email,
      );
    }
    final visible =
        people.values
            .where(
              (user) => '${user.name} ${user.email}'.toLowerCase().contains(
                _query.toLowerCase(),
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          key: const Key('channel-members-sheet'),
          height: MediaQuery.sizeOf(context).height * .82,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.close,
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 22),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: TextField(
                    key: const Key('channel-members-search'),
                    enabled: !_saving,
                    decoration: InputDecoration(
                      hintText: strings.search,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    key: const Key('channel-members-list'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${strings.workspaceMembers} · ${people.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (!widget.canManage)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    strings.readOnly,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text(strings.empty)),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final user = visible[index];
                              return CheckboxListTile(
                                key: ValueKey('channel-member-${user.userId}'),
                                contentPadding: EdgeInsets.zero,
                                secondary: UserAvatar(
                                  size: 34,
                                  userId: user.userId,
                                  name: user.name,
                                  avatarUrl: user.avatarUrl,
                                ),
                                title: Text(
                                  user.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: user.email.isEmpty
                                    ? null
                                    : Text(
                                        user.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                value: _ids.contains(user.userId),
                                onChanged: _saving || !widget.canManage
                                    ? null
                                    : (value) => setState(() {
                                        if (value == true) {
                                          _ids.add(user.userId);
                                        } else {
                                          _ids.remove(user.userId);
                                        }
                                      }),
                              );
                            },
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        tr(context, _error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      if (widget.canManage) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            child: Text(strings.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          key: widget.canManage
                              ? const Key('channel-members-save')
                              : const Key('channel-members-close'),
                          onPressed: _saving
                              ? null
                              : widget.canManage
                              ? _save
                              : () => Navigator.pop(context),
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.canManage
                                      ? strings.save
                                      : strings.close,
                                ),
                        ),
                      ),
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

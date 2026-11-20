import '../../../../core/widgets/app_snack_bar.dart';
import '../widgets/messenger_refresh_lifecycle.dart';
import '../widgets/message_interactions.dart';
import '../../../calls/domain/entities/call_room.dart';
import '../../../calls/presentation/call_cubit.dart';
import '../../../../core/storage/workspace_selection_storage.dart';
import '../../../storage/data/storage_models.dart';
import '../widgets/message_actions.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../../data/services/chat_media_payload.dart';
import '../widgets/file_attachment_sheet.dart';
import '../widgets/video_note_capture.dart';
import '../widgets/video_note_message.dart';
import '../widgets/voice_composer.dart';
import '../widgets/voice_message.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/services/chat_attachment_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../widgets/shared_task_message.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/conversation_cubit.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversation,
    this.initialMessageId,
  });
  final String? initialMessageId;
  final ChatConversationModel conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with MessengerRefreshLifecycle<ConversationScreen> {
  late ConversationCubit _refreshCubit;
  @override
  String get messengerRefreshPath => '/messenger/${widget.conversation.id}';
  @override
  bool get isMessengerConversation => true;
  @override
  void setMessengerRefresh(bool active) => _refreshCubit.setAutoRefresh(active);
  @override
  void invalidateMessenger() => _refreshCubit.invalidate();
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  String? _focusedReplyId;
  final _messageScroll = ScrollController();
  bool _hasText = false;
  bool _searching = false;
  String _searchQuery = '';
  String? _storageMessageId;
  String? _currentUserId;
  List<ChatConversationModel> _people = const [];
  final _sentMessageIds = <String>{};

  @override
  void initState() {
    super.initState();
    _refreshCubit = context.read<ConversationCubit>();
    _composerFocus.addListener(_onComposerFocus);
    _storageMessageId = widget.initialMessageId;
    _loadPeople();
  }

  void _onComposerFocus() {
    if (!_composerFocus.hasFocus) _refreshCubit.stopTyping();
  }

  Future<void> _loadPeople() async {
    await Future.wait([
      if (sl.isRegistered<ProfileRepository>())
        (() async {
          try {
            final profile = await sl<ProfileRepository>().getCurrentUser();
            if (mounted) setState(() => _currentUserId = profile.id);
          } catch (_) {
            /* Messages remain readable if profile loading fails. */
          }
        })(),
      if (sl.isRegistered<ChatRepository>())
        (() async {
          try {
            final chats = await sl<ChatRepository>().getConversations();
            if (mounted) {
              setState(
                () => _people = chats.where((chat) => !chat.isChannel).toList(),
              );
            }
          } catch (_) {
            /* Unresolved mentions still display their names. */
          }
        })(),
    ]);
  }

  Future<void> _startCall(bool video) async {
    final calls = sl<CallCubit>();
    if (calls.state.busy) {
      await context.push('/call');
      return;
    }
    if (calls.state.incoming != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.info,
          content: Text('Сначала ответьте на входящий звонок.'),
        ),
      );
      return;
    }
    try {
      final workspaceId = await sl<WorkspaceSelectionStorage>().read();
      if (workspaceId == null) {
        throw const ChatException('Выберите рабочее пространство.');
      }
      final chat = widget.conversation;
      List<String> invitees = [chat.id];
      if (chat.isChannel) {
        final repository = sl<ChatRepository>();
        if (repository is! ChatActionsRepository) {
          throw const ChatException('Не удалось загрузить участников канала.');
        }
        final userId =
            _currentUserId ??
            (await sl<ProfileRepository>().getCurrentUser()).id;
        final members =
            (await (repository as ChatActionsRepository).channelMembers(
              chat.id,
            )).where((e) => e.userId != userId).toList();
        if (members.isEmpty) {
          throw const ChatException('В канале нет других участников.');
        }
        if (!mounted) return;
        final selected = members.map((e) => e.userId).toSet();
        final result = await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .65,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Участники звонка',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final member in members)
                            CheckboxListTile(
                              title: Text(member.name),
                              value: selected.contains(member.userId),
                              onChanged: (value) => setSheetState(() {
                                if (value == true) {
                                  selected.add(member.userId);
                                } else {
                                  selected.remove(member.userId);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => context.pop(selected.toList()),
                        child: const Text('Позвонить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (result == null) return;
        invitees = result;
      }
      if (!mounted) return;
      final connection = calls.start(
        workspaceId: workspaceId,
        invitees: invitees,
        video: video,
        threadId: chat.threadId,
        title: chat.title,
      );
      await context.push('/call');
      await connection;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(
              e is ChatException ? e.message : 'Не удалось начать звонок.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openStorage() async {
    final workspaceId = await sl<WorkspaceSelectionStorage>().read();
    if (!mounted || workspaceId == null) return;
    final messageId = await context.push<String>(
      '/storage',
      extra: StorageScope(
        source: StorageSource.chat,
        id: widget.conversation.threadId,
        workspaceId: workspaceId,
        title: widget.conversation.title,
      ),
    );
    if (!mounted) return;
    await context.read<ConversationCubit>().load();
    if (mounted && messageId != null) {
      setState(() {
        _storageMessageId = messageId;
        _searchQuery = '';
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _composerFocus.removeListener(_onComposerFocus);
    _composerFocus.dispose();
    _messageScroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.conversation;
    return Scaffold(
      backgroundColor: AppColors.chatCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          key: const Key('conversation-back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft, size: AppIconSizes.standard),
        ),
        titleSpacing: AppSpacing.xs,
        title: _searching
            ? TextField(
                key: const Key('conversation-search'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск в переписке',
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              )
            : Row(
                children: [
                  _Avatar(conversation: chat, size: AppSpacing.xl),
                  const SizedBox(width: AppSpacing.smMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.isChannel
                              ? '# ${chat.title.replaceFirst(RegExp(r'^#\s*'), '')}'
                              : chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title(
                            context,
                          )?.copyWith(color: AppColors.ink),
                        ),
                        Text(
                          chat.isChannel
                              ? 'Канал'
                              : chat.isOnline
                              ? 'в сети'
                              : 'Личная переписка',
                          style: AppTypography.caption(context)?.copyWith(
                            color: !chat.isChannel && chat.isOnline
                                ? AppColors.accent
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (!_searching && sl.isRegistered<CallCubit>()) ...[
            IconButton(
              tooltip: 'Аудиозвонок',
              onPressed: () => _startCall(false),
              icon: const Icon(LucideIcons.phone, size: 18),
            ),
            IconButton(
              tooltip: 'Видеозвонок',
              onPressed: () => _startCall(true),
              icon: const Icon(LucideIcons.video, size: 18),
            ),
          ],
          IconButton(
            tooltip: _searching ? 'Закрыть поиск' : 'Поиск в переписке',
            onPressed: () => setState(() {
              _searching = !_searching;
              _searchQuery = '';
            }),
            icon: Icon(
              _searching ? LucideIcons.x : LucideIcons.search,
              size: AppIconSizes.standard,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: BlocConsumer<ConversationCubit, ConversationState>(
          listenWhen: (previous, current) =>
              previous.replyTo?.id != current.replyTo?.id ||
              previous.messages.lastOrNull?.id !=
                  current.messages.lastOrNull?.id ||
              (previous.error != current.error &&
                  current.error != null &&
                  (previous.isSending || current.messages.isNotEmpty)),
          listener: (context, state) {
            if (_focusedReplyId != state.replyTo?.id) {
              _focusedReplyId = state.replyTo?.id;
              if (_focusedReplyId != null) _composerFocus.requestFocus();
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                appSnackBar(
                  context: context,
                  tone: AppSnackBarTone.error,
                  content: Text(state.error!),
                ),
              );
            }
            if (_messageScroll.hasClients &&
                _messageScroll.position.pixels > 80) {
              final offset = _messageScroll.position.pixels;
              final extent = _messageScroll.position.maxScrollExtent;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_messageScroll.hasClients) return;
                final position = _messageScroll.position;
                // Keep the same part of history visible when newer rows arrive.
                _messageScroll.jumpTo(
                  (offset + position.maxScrollExtent - extent).clamp(
                    position.minScrollExtent,
                    position.maxScrollExtent,
                  ),
                );
              });
            }
          },
          builder: (context, state) => Column(
            children: [
              ConversationSections(onStoragePressed: _openStorage),
              PinnedMessagesBar(
                messages: state.messages,
                onSelect: (id) => setState(() => _storageMessageId = id),
              ),
              if (_storageMessageId != null)
                MaterialBanner(
                  content: const Text('Выбранное сообщение'),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _storageMessageId = null),
                      child: const Text('Показать все'),
                    ),
                  ],
                ),
              Expanded(
                child: _MessageList(
                  scrollController: _messageScroll,
                  state: state,
                  conversation: chat,
                  currentUserId: _currentUserId,
                  sentMessageIds: _sentMessageIds,
                  people: _people,
                  searchQuery: _searchQuery,
                  focusedMessageId: _storageMessageId,
                ),
              ),
              if (state.typingUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${state.typingUsers.take(3).map((e) => e.name).join(', ')} ${state.typingUsers.length == 1 ? 'печатает…' : 'печатают…'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              if (state.replyTo != null)
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.reply,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    'Ответ: ${state.replyTo!.authorName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                  subtitle: Text(
                    state.replyTo!.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Отменить ответ',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _refreshCubit.selectReply(null),
                  ),
                ),
              _Composer(
                focusNode: _composerFocus,
                controller: _controller,
                hasText: _hasText,
                isSending: state.isSending,
                channelName: chat.isChannel ? chat.title : null,
                onChanged: (value) {
                  _refreshCubit.notifyTyping(value);
                  setState(() => _hasText = value.trim().isNotEmpty);
                },
                onSend: _send,
                onVoiceSend: _sendVoice,
                onFiles: _pickFiles,
                onVideo: _recordVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _sendMedia(String text, String dataUrl, {int? seconds}) async {
    if (!mounted) return false;
    final cubit = context.read<ConversationCubit>();
    final sent = await cubit.sendAttachment(
      text: text,
      dataUrl: dataUrl,
      duration: seconds,
    );
    if (sent && mounted) {
      setState(() => _sentMessageIds.add(cubit.state.messages.last.id));
    }
    return sent;
  }

  Future<void> _pickFiles() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final files = await FilePicker.pickFiles();
      if (!mounted || files.isEmpty) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => FileAttachmentSheet(files: files, onSend: _sendMedia),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text('Не удалось выбрать файлы. Попробуйте ещё раз.'),
          ),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
        child: VideoNoteCapture(
          onSend: (path, seconds) async {
            final file = File(path);
            if (await file.length() > ChatMediaPayload.maxFileBytes) {
              throw const FormatException('Видеозаметка слишком большая.');
            }
            final bytes = await file.readAsBytes();
            final url = ChatMediaPayload.dataUrl(
              'video.mp4',
              bytes,
              mimeType: 'video/mp4',
            );
            return _sendMedia('📹 видео $secondsс', url, seconds: seconds);
          },
        ),
      ),
    );
  }

  Future<bool> _sendVoice(String path, int seconds) async {
    final cubit = context.read<ConversationCubit>();
    final data = await File(path).readAsBytes();
    if (data.isEmpty) {
      throw const FormatException('Запись не содержит аудио');
    }
    if (!mounted) return false;
    final sent = await cubit.sendVoice(
      'data:audio/mp4;base64,${base64Encode(data)}',
      seconds,
    );
    if (sent && mounted) {
      setState(() {
        _sentMessageIds.add(cubit.state.messages.last.id);
      });
    }
    return sent;
  }

  Future<void> _send() async {
    if (!_hasText) return;
    final sent = await context.read<ConversationCubit>().send(_controller.text);
    if (sent && mounted) {
      _controller.clear();
      setState(() {
        _hasText = false;
        final messages = context.read<ConversationCubit>().state.messages;
        if (messages.isNotEmpty) _sentMessageIds.add(messages.last.id);
      });
    }
  }
}

class ConversationSections extends StatelessWidget {
  const ConversationSections({super.key, required this.onStoragePressed});

  final VoidCallback onStoragePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: AppSpacing.touchTarget,
        child: Row(
          children: <Widget>[
            const Expanded(
              child: ConversationSectionButton(
                label: 'Переписка',
                icon: LucideIcons.messageCircle,
                selected: true,
              ),
            ),
            Expanded(
              child: ConversationSectionButton(
                key: const Key('conversation-storage'),
                label: 'Кладовка',
                icon: LucideIcons.archive,
                onPressed: onStoragePressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationSectionButton extends StatelessWidget {
  const ConversationSectionButton({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: selected ? null : onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    bottom: BorderSide(
                      color: AppColors.accent,
                      width: AppSpacing.xxs,
                    ),
                  )
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: AppIconSizes.standard, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTypography.body(context)?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.scrollController,
    required this.state,
    required this.conversation,
    required this.currentUserId,
    required this.sentMessageIds,
    required this.people,
    this.searchQuery = '',
    this.focusedMessageId,
  });
  final String? currentUserId;
  final String searchQuery;
  final String? focusedMessageId;
  final Set<String> sentMessageIds;
  final ScrollController scrollController;
  final List<ChatConversationModel> people;
  final ConversationState state;
  final ChatConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.messages.isEmpty) {
      return _CenteredState(
        icon: LucideIcons.wifiOff,
        title: state.error!,
        action: TextButton(
          onPressed: context.read<ConversationCubit>().load,
          child: const Text('Повторить'),
        ),
      );
    }
    if (state.messages.isEmpty) {
      return _CenteredState(
        icon: conversation.isChannel
            ? LucideIcons.hash
            : LucideIcons.messageCircle,
        title: conversation.isChannel
            ? 'Это начало канала #${conversation.title}'
            : 'Начните переписку с ${conversation.title}',
      );
    }
    final messages =
        state.messages
            .where(
              (message) =>
                  searchQuery.isEmpty ||
                  '${message.text} ${message.authorName}'
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()),
            )
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    if (focusedMessageId != null) {
      final index = messages.indexWhere(
        (message) => message.id == focusedMessageId,
      );
      if (index < 0) {
        return const _CenteredState(
          icon: LucideIcons.messageCircle,
          title: 'Исходное сообщение больше недоступно',
        );
      }
      if (index > 0) {
        messages.removeRange(0, index);
      }
    }
    if (messages.isEmpty) {
      return const _CenteredState(
        icon: LucideIcons.search,
        title: 'Сообщения не найдены',
      );
    }
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    bool grouped(ChatMessageModel a, ChatMessageModel b) =>
        a.authorId == b.authorId &&
        sameDay(a.createdAt, b.createdAt) &&
        a.createdAt.difference(b.createdAt).inMinutes.abs() < 5;
    String dateLabel(DateTime date) {
      final now = DateTime.now();
      if (sameDay(date, now)) return 'Сегодня';
      if (sameDay(date, now.subtract(const Duration(days: 1)))) return 'Вчера';
      const months = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря',
      ];
      return '${date.day} ${months[date.month - 1]}${date.year == now.year ? '' : ' ${date.year}'}';
    }

    return RefreshIndicator(
      onRefresh: context.read<ConversationCubit>().load,
      child: ListView.builder(
        controller: scrollController,
        key: PageStorageKey(
          'conversation-messages-${conversation.threadId}-${focusedMessageId ?? ''}',
        ),
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.smMd,
        ),
        itemCount: messages.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = messages.indexWhere(
            (message) => message.id == key.value,
          );
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) {
          final message = messages[index];
          final older = index + 1 < messages.length
              ? messages[index + 1]
              : null;
          final newer = index > 0 ? messages[index - 1] : null;
          final groupStart = older == null || !grouped(message, older);
          final groupEnd = newer == null || !grouped(message, newer);
          return Column(
            key: ValueKey(message.id),
            children: [
              if (older == null || !sameDay(message.createdAt, older.createdAt))
                ConversationDateDivider(label: dateLabel(message.createdAt)),
              _MessageRow(
                message: messages[index],
                people: people,
                showAuthor: conversation.isChannel && groupStart,
                showAvatar: conversation.isChannel && groupEnd,
                reserveAvatar: conversation.isChannel,
                groupStart: groupStart,
                groupEnd: groupEnd,
                isMine:
                    (currentUserId != null &&
                        currentUserId!.isNotEmpty &&
                        messages[index].authorId == currentUserId) ||
                    sentMessageIds.contains(messages[index].id),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ConversationDateDivider extends StatelessWidget {
  const ConversationDateDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.mdLg),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smMd),
            child: Text(
              label,
              style: AppTypography.caption(
                context,
              )?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isMine,
    required this.people,
    this.showAuthor = true,
    this.showAvatar = true,
    this.reserveAvatar = true,
    this.groupStart = true,
    this.groupEnd = true,
  });
  final ChatMessageModel message;
  final bool isMine;
  final bool showAuthor, showAvatar, reserveAvatar, groupStart, groupEnd;
  final List<ChatConversationModel> people;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.createdAt).format(context);
    return Padding(
      key: Key('message-row-${message.id}'),
      padding: EdgeInsets.only(
        top: groupStart ? AppSpacing.sm : AppSpacing.xxs,
        bottom: groupEnd ? AppSpacing.xs : AppSpacing.xxs,
      ),
      child: GestureDetector(
        onLongPress: () => showMessageActions(context, message, isMine),
        child: Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine && reserveAvatar) ...[
              if (showAvatar)
                _MessageAvatar(message: message)
              else
                const SizedBox(width: AppSpacing.xl),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.76,
                ),
                child: Container(
                  key: Key('message-bubble-${message.id}'),
                  constraints: const BoxConstraints(minWidth: 60),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.smMd,
                    AppSpacing.sm,
                    AppSpacing.smMd,
                    AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: message.kind == ChatMessageKind.videoMessage
                        ? Colors.transparent
                        : isMine
                        ? AppColors.outgoingMessage
                        : AppColors.canvas,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        !isMine && !groupStart ? AppRadius.xs : AppRadius.lg,
                      ),
                      topRight: Radius.circular(
                        isMine && !groupStart ? AppRadius.xs : AppRadius.lg,
                      ),
                      bottomLeft: Radius.circular(
                        !isMine && groupEnd ? AppRadius.xs : AppRadius.lg,
                      ),
                      bottomRight: Radius.circular(
                        isMine && groupEnd ? AppRadius.xs : AppRadius.lg,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.mdLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMine && showAuthor) ...[
                              Text(
                                message.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                            _MessageBody(
                              message: message,
                              people: people,
                              isMine: isMine,
                            ),
                            if (message.reactions.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              MessageReactionBar(message: message),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.pinned) ...[
                              const Icon(
                                Icons.push_pin_outlined,
                                size: 12,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (message.favorited) ...[
                              const Icon(
                                LucideIcons.bookmark,
                                size: AppIconSizes.standard,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              time,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: AppColors.muted,
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
          ],
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.people,
    this.renderTask = true,
    this.isMine = false,
  });
  final bool renderTask;
  final bool isMine;
  final List<ChatConversationModel> people;

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final quote = message.quote;
    if (message.text.startsWith('↪ ')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text(
              'Переслано',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          _MessageBody(
            message: message.copyWith(text: message.text.substring(2)),
            people: people,
            renderTask: renderTask,
            isMine: isMine,
          ),
        ],
      );
    }
    if (quote != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smMd,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.quoteSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: const Border(
                left: BorderSide(color: AppColors.accent, width: AppSpacing.xs),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.author,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  quote.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MessageBody(
            message: message.copyWith(text: quote.body),
            people: people,
            renderTask: renderTask,
            isMine: isMine,
          ),
        ],
      );
    }
    if (message.kind == ChatMessageKind.videoMessage) {
      return VideoNoteMessage(message: message);
    }
    if (message.kind == ChatMessageKind.audio) {
      return VoiceMessage(message: message);
    }
    if (message.isCall) return _CallMessage(message: message, isMine: isMine);
    if (message.isFile) return _AttachmentMessage(message: message);
    if (renderTask) {
      final link = sharedTaskLink(message.text, message.taskRef);
      if (link != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (link.before.trim().isNotEmpty) ...[
              _MessageBody(
                message: message.copyWith(text: link.before),
                people: people,
                renderTask: false,
              ),
              const SizedBox(height: 8),
            ],
            SharedTaskMessage(
              taskId: link.taskId,
              title: link.title,
              displayId: link.displayId,
              projectId: link.projectId,
            ),
            if (link.after.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _MessageBody(
                message: message.copyWith(text: link.after),
                people: people,
                renderTask: false,
              ),
            ],
          ],
        );
      }
    }
    final style = AppTypography.body(
      context,
    )!.copyWith(height: 1.4, color: AppColors.ink);
    final matches = RegExp(r'@\[([^\]]+)\]').allMatches(message.text);
    final spans = <InlineSpan>[];
    var position = 0;
    for (final match in matches) {
      if (match.start > position) {
        spans.add(
          TextSpan(text: message.text.substring(position, match.start)),
        );
      }
      final name = match.group(1)!;
      final candidates = people
          .where(
            (person) =>
                person.title.trim().toLowerCase() == name.trim().toLowerCase(),
          )
          .toList();
      final person = candidates.length == 1 ? candidates.single : null;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            key: Key('mention-${message.id}-${match.start}'),
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showMention(context, name, person),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.73 - 30,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Avatar(
                      conversation:
                          person ??
                          ChatConversationModel(
                            id: '',
                            threadId: '',
                            title: name,
                            isChannel: false,
                          ),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '@$name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.accent.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      position = match.end;
    }
    spans.add(TextSpan(text: message.text.substring(position)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      textWidthBasis: TextWidthBasis.longestLine,
    );
  }
}

void _showMention(
  BuildContext context,
  String name,
  ChatConversationModel? person,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: BoxConstraints.tightFor(
      width: MediaQuery.sizeOf(context).width,
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(
              conversation:
                  person ??
                  ChatConversationModel(
                    id: '',
                    threadId: '',
                    title: name,
                    isChannel: false,
                  ),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (person != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.push(
                    '/messenger/${Uri.encodeComponent(person.id)}',
                    extra: person,
                  );
                },
                icon: const Icon(
                  LucideIcons.messageCircle,
                  size: AppIconSizes.standard,
                ),
                label: const Text('Написать сообщение'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _AttachmentMessage extends StatefulWidget {
  const _AttachmentMessage({required this.message});
  final ChatMessageModel message;

  @override
  State<_AttachmentMessage> createState() => _AttachmentMessageState();
}

class _AttachmentMessageState extends State<_AttachmentMessage> {
  Future<Uint8List>? _bytes;
  bool _opening = false;
  ChatMessageModel get message => widget.message;

  @override
  void initState() {
    super.initState();
    if (message.isImageAttachment) _reload();
  }

  void _reload() {
    final dataUrl = message.attachmentDataUrl;
    if (dataUrl != null) {
      _bytes = Future.sync(() => ChatAttachmentLoader.decodePayload(dataUrl));
      return;
    }
    _bytes = sl.isRegistered<Dio>()
        ? ChatAttachmentLoader(sl<Dio>()).load(message.id)
        : Future.error(StateError('Нет подключения к серверу'));
  }

  @override
  Widget build(BuildContext context) {
    if (!message.isImageAttachment) {
      return InkWell(
        onTap: _opening ? null : _openFile,
        child: _opening
            ? const SizedBox(
                width: 180,
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              )
            : _FileCard(message: message),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InkWell(
            onTap: () => setState(_reload),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FileCard(message: message, failedPreview: true),
                const Text('Повторить загрузку'),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 260,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snapshot.data!;
        return InkWell(
          key: Key('image-attachment-${message.id}'),
          onTap: () => _showImage(bytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 280,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _FileCard(message: message, failedPreview: true),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFile() async {
    setState(() => _opening = true);
    try {
      final bytes = message.attachmentDataUrl != null
          ? ChatAttachmentLoader.decodePayload(message.attachmentDataUrl!)
          : await ChatAttachmentLoader(sl<Dio>()).load(message.id);
      final directory = await getTemporaryDirectory();
      final safeId = message.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final folder = await Directory(
        '${directory.path}/chat-attachments/$safeId',
      ).create(recursive: true);
      final name = (message.fileName ?? 'attachment').replaceAll(
        RegExp(r'[/\\]'),
        '_',
      );
      final file = await File(
        '${folder.path}/$name',
      ).writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) throw Exception(result.message);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text('Не удалось открыть файл. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showImage(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.message, this.failedPreview = false});

  final ChatMessageModel message;
  final bool failedPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('file-attachment-${message.id}'),
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(AppSpacing.smMd),
      decoration: BoxDecoration(
        color: AppColors.quoteSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              failedPreview ? LucideIcons.imageOff : LucideIcons.file,
              color: AppColors.accent,
              size: AppIconSizes.standard,
            ),
          ),
          const SizedBox(width: AppSpacing.smMd),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? message.attachmentLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(context)?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message.text.contains(' · ')) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message.text.split(' · ').skip(1).join(' · '),
                    style: AppTypography.caption(
                      context,
                    )?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallMessage extends StatelessWidget {
  const _CallMessage({required this.message, required this.isMine});

  final ChatMessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final video = message.callMode?.toLowerCase() == 'video';
    final status = message.callStatus?.toLowerCase();
    final missed = status == 'missed' || status == 'unanswered';
    final declined = status == 'declined' || status == 'rejected';
    final failed =
        status == 'failed' || status == 'cancelled' || status == 'canceled';
    final color = missed || declined || failed
        ? AppColors.error
        : AppColors.accent;
    final title = video ? 'Видеозвонок' : 'Аудиозвонок';
    final detail = missed
        ? 'Пропущенный'
        : declined
        ? 'Отклонён'
        : failed
        ? 'Отменён'
        : message.formattedDuration ??
              (status == 'ended'
                  ? 'Завершён'
                  : (isMine ? 'Исходящий' : 'Входящий'));
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: !sl.isRegistered<CallCubit>()
          ? null
          : () async {
              final calls = sl<CallCubit>();
              if (calls.state.busy) {
                await context.push('/call');
                return;
              }
              if (status != 'started' && status != 'active') {
                await context
                    .findAncestorStateOfType<_ConversationScreenState>()
                    ?._startCall(video);
                return;
              }
              try {
                final payload = jsonDecode(message.text);
                final id = payload is Map ? payload['callId'] : null;
                final workspaceId = await sl<WorkspaceSelectionStorage>()
                    .read();
                if (id is! String || workspaceId == null || !context.mounted) {
                  return;
                }
                final room = CallRoom(
                  id: id,
                  workspaceId: workspaceId,
                  mode: video ? 'video' : 'audio',
                  title: message.callTitle ?? title,
                  threadId: message.threadId,
                );
                final pending = calls.accept(room, creator: isMine);
                await context.push('/call');
                await pending;
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    appSnackBar(
                      context: context,
                      tone: AppSnackBarTone.info,
                      content: Text('Звонок недоступен.'),
                    ),
                  );
                }
              }
            },
      child: Padding(
        key: Key('call-message-${message.id}'),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                video ? LucideIcons.video : LucideIcons.phone,
                color: color,
                size: AppIconSizes.standard,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMine
                            ? LucideIcons.arrowUpRight
                            : LucideIcons.arrowDownLeft,
                        size: AppIconSizes.standard,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          detail,
                          style: GoogleFonts.manrope(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.message});
  final ChatMessageModel message;
  @override
  Widget build(BuildContext context) => UserAvatar(
    size: AppSpacing.xl,
    userId: message.authorId,
    name: message.authorName,
    avatarUrl: message.authorAvatarUrl,
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation, required this.size});
  final ChatConversationModel conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (conversation.isChannel) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          LucideIcons.hash,
          size: AppIconSizes.standard,
          color: AppColors.accent,
        ),
      );
    }
    return UserAvatar(
      size: size,
      userId: conversation.id,
      name: conversation.title,
      avatarUrl: conversation.avatarUrl,
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hasText,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
    required this.onVoiceSend,
    required this.onFiles,
    required this.onVideo,
    this.channelName,
    this.focusNode,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasText;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final Future<bool> Function(String, int) onVoiceSend;
  final VoidCallback onFiles;
  final VoidCallback onVideo;
  final String? channelName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.smMd,
      AppSpacing.smMd,
    ),
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: VoiceComposer(
      hasText: hasText,
      isSending: isSending,
      onTextSend: onSend,
      onVoiceSend: onVoiceSend,
      onFiles: onFiles,
      onVideo: onVideo,
      textField: TextField(
        focusNode: focusNode,
        key: const Key('conversation-composer'),
        controller: controller,
        minLines: 1,
        maxLines: 5,
        onChanged: onChanged,
        onSubmitted: (_) => onSend(),
        decoration: InputDecoration(
          hintText: 'Сообщение',
          filled: true,
          fillColor: AppColors.subtleSurface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smMd,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    ),
  );
}

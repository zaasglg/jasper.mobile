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
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/conversation_cubit.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversation});
  final ChatConversationModel conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  bool _hasText = false;
  String? _currentUserId;
  List<ChatConversationModel> _people = const [];
  final _sentMessageIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadPeople();
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.conversation;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          key: const Key('conversation-back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        titleSpacing: 2,
        title: Row(
          children: [
            _Avatar(conversation: chat, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.isChannel ? '# ${chat.title}' : chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!chat.isChannel && chat.isOnline)
                    Text(
                      'в сети',
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.search, size: 21),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: BlocConsumer<ConversationCubit, ConversationState>(
          listenWhen: (previous, current) =>
              previous.error != current.error && current.error != null,
          listener: (context, state) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          },
          builder: (context, state) => Column(
            children: [
              Expanded(
                child: _MessageList(
                  state: state,
                  conversation: chat,
                  currentUserId: _currentUserId,
                  sentMessageIds: _sentMessageIds,
                  people: _people,
                ),
              ),
              _Composer(
                controller: _controller,
                hasText: _hasText,
                isSending: state.isSending,
                channelName: chat.isChannel ? chat.title : null,
                onChanged: (value) =>
                    setState(() => _hasText = value.trim().isNotEmpty),
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
          const SnackBar(
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

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.conversation,
    required this.currentUserId,
    required this.sentMessageIds,
    required this.people,
  });
  final String? currentUserId;
  final Set<String> sentMessageIds;
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
    final messages = state.messages.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return RefreshIndicator(
      onRefresh: context.read<ConversationCubit>().load,
      child: ListView.builder(
        key: PageStorageKey('conversation-messages-${conversation.threadId}'),
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        itemCount: messages.length,
        itemBuilder: (context, index) => _MessageRow(
          message: messages[index],
          people: people,
          isMine:
              (currentUserId != null &&
                  currentUserId!.isNotEmpty &&
                  messages[index].authorId == currentUserId) ||
              sentMessageIds.contains(messages[index].id),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isMine,
    required this.people,
  });
  final ChatMessageModel message;
  final bool isMine;
  final List<ChatConversationModel> people;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.createdAt).format(context);
    return Padding(
      key: Key('message-row-${message.id}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _MessageAvatar(message: message),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.73,
              ),
              child: Container(
                key: Key('message-bubble-${message.id}'),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                decoration: BoxDecoration(
                  color: isMine
                      ? const Color(0xFFE8E2FF)
                      : const Color(0xFFF3F4F7),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMine) ...[
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
                      const SizedBox(height: 4),
                    ],
                    _MessageBody(message: message, people: people),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        time,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            _MessageAvatar(message: message),
          ],
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.people,
    this.renderTask = true,
  });
  final bool renderTask;
  final List<ChatConversationModel> people;

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.videoMessage) {
      return VideoNoteMessage(message: message);
    }
    if (message.kind == ChatMessageKind.audio) {
      return VoiceMessage(message: message);
    }
    if (message.isCall) return _CallMessage(message: message);
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
    final style = GoogleFonts.manrope(
      fontSize: 13,
      height: 1.45,
      color: const Color(0xFF3F3B42),
    );
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
    return Text.rich(TextSpan(style: style, children: spans));
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
                icon: const Icon(LucideIcons.messageCircle, size: 18),
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
          const SnackBar(
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
                  icon: const Icon(LucideIcons.x),
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
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.subtleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              failedPreview ? LucideIcons.imageOff : LucideIcons.file,
              color: AppColors.accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? message.attachmentLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message.text.contains(' · ')) ...[
                  const SizedBox(height: 2),
                  Text(
                    message.text.split(' · ').skip(1).join(' · '),
                    style: GoogleFonts.manrope(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
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
  const _CallMessage({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (message.callTitle != null) message.callTitle!,
      if (message.formattedDuration != null) message.formattedDuration!,
    ];
    return Container(
      key: Key('call-message-${message.id}'),
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              message.callMode?.toLowerCase() == 'video'
                  ? LucideIcons.video
                  : LucideIcons.phone,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.callHeading,
                  style: GoogleFonts.manrope(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
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

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.message});
  final ChatMessageModel message;
  @override
  Widget build(BuildContext context) => UserAvatar(
    size: 36,
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
          color: Colors.white24,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(LucideIcons.hash, size: 20),
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
  });
  final TextEditingController controller;
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
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
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
        key: const Key('conversation-composer'),
        controller: controller,
        minLines: 1,
        maxLines: 5,
        onChanged: onChanged,
        onSubmitted: (_) => onSend(),
        decoration: InputDecoration(
          hintText: channelName == null
              ? 'Сообщение'
              : 'Сообщение #$channelName',
          filled: true,
          fillColor: AppColors.subtleSurface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    ),
  );
}

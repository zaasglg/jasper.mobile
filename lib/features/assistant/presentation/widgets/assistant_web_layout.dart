import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../storage/presentation/storage_file_screen.dart';
import '../../data/models/assistant_message_model.dart';

abstract final class _AiColors {
  static const ink = Color(0xFF1C1C2B);
  static const muted = Color(0xFF82829E);
  static const surface = Color(0xFFF7F7F5);
}

class AssistantWebHeader extends StatelessWidget {
  const AssistantWebHeader({
    super.key,
    required this.workspaceName,
    required this.onStopVoice,
    required this.onVoiceHelp,
  });
  final String workspaceName;
  final VoidCallback onStopVoice, onVoiceHelp;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset('assets/images/JBee.svg'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ai',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _AiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'AI-агент · задачи и проекты',
                    style: TextStyle(fontSize: 12, color: _AiColors.muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия помощника',
              onSelected: (v) => v == 'voice' ? onStopVoice() : onVoiceHelp(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'voice',
                  child: Text('Остановить озвучивание'),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: Text('Голосовой вызов'),
                ),
              ],
              icon: const Icon(
                LucideIcons.ellipsis,
                size: 18,
                color: _AiColors.muted,
              ),
            ),
            IconButton(
              tooltip: 'Закрыть',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(LucideIcons.x, size: 18, color: _AiColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const Icon(
              LucideIcons.folderKanban,
              size: 14,
              color: _AiColors.muted,
            ),
            const SizedBox(width: 8),
            const Text(
              'Контекст',
              style: TextStyle(fontSize: 12, color: _AiColors.muted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                workspaceName.isEmpty
                    ? 'Рабочее пространство не выбрано'
                    : workspaceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _AiColors.ink),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class AssistantWebWelcome extends StatelessWidget {
  const AssistantWebWelcome({
    super.key,
    required this.hasWorkspace,
    required this.onSuggestion,
  });
  final bool hasWorkspace;
  final ValueChanged<String> onSuggestion;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        hasWorkspace ? 'Что поручим агенту?' : 'Выберите рабочее пространство',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -.35,
          height: 1.3,
          color: _AiColors.ink,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        hasWorkspace
            ? 'Найду нужные данные, покажу задачи и сроки, подготовлю новую задачу или изменения существующей.'
            : 'Выберите пространство в боковом меню — тогда агент сможет работать с его задачами, проектами и сообщениями.',
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: _AiColors.muted,
        ),
      ),
      if (hasWorkspace) ...[
        const SizedBox(height: 28),
        const Text(
          'Начните с поручения',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _AiColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in [
          (
            icon: LucideIcons.search,
            title: 'Найти информацию',
            description: 'Задачи, файлы и сообщения',
            prompt: 'Помоги найти информацию в рабочем пространстве: ',
          ),
          (
            icon: LucideIcons.listTodo,
            title: 'Мои задачи',
            description: 'Мои задачи на ближайшее время',
            prompt: 'Какие мои задачи на ближайшее время и какие просрочены?',
          ),
          (
            icon: LucideIcons.shieldCheck,
            title: 'Проверить риски',
            description: 'Что может задержать проект',
            prompt: 'Проанализируй риски проекта: ',
          ),
          (
            icon: LucideIcons.folderKanban,
            title: 'Подготовить задачу',
            description: 'Черновик перед созданием',
            prompt: 'Подготовь черновик задачи: ',
          ),
        ])
          TextButton(
            onPressed: () => onSuggestion(item.prompt),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
              foregroundColor: _AiColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _AiColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.arrowUpRight,
                  size: 16,
                  color: _AiColors.muted,
                ),
              ],
            ),
          ),
      ],
    ],
  );
}

class AssistantWebMessage extends StatelessWidget {
  const AssistantWebMessage({super.key, required this.message});
  final AssistantMessageModel message;
  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (user)
            const Text(
              'Вы',
              style: TextStyle(fontSize: 14, color: _AiColors.muted),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset('assets/images/JBee.svg'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ai',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _AiColors.ink,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * (user ? .88 : 1),
            ),
            padding: user
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                : EdgeInsets.zero,
            decoration: user
                ? BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final image in message.images)
                          AssistantImageThumb(data: image, size: 64),
                      ],
                    ),
                  ),
                if (user)
                  SelectableText(
                    message.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: _AiColors.ink,
                    ),
                  )
                else
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: const TextStyle(
                            fontSize: 14,
                            height: 1.65,
                            color: _AiColors.ink,
                          ),
                          h1: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          h2: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          h3: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          a: const TextStyle(color: AppColors.accent),
                          blockSpacing: 8,
                          codeblockDecoration: BoxDecoration(
                            color: _AiColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tableBorder: TableBorder.all(color: AppColors.border),
                        ),
                    onTapLink: (text, href, title) {
                      final uri = Uri.tryParse(href ?? '');
                      if (uri == null) return;
                      final internal =
                          (!uri.hasAuthority && !uri.hasScheme) ||
                          uri.host == 'jospar.me';
                      final taskId = uri.queryParameters['taskId'];
                      if (internal && uri.path == '/tasks' && taskId != null) {
                        context.push('/tasks/${Uri.encodeComponent(taskId)}');
                      } else if (internal &&
                          RegExp(r'^/tasks/[^/]+$').hasMatch(uri.path)) {
                        context.push(uri.path);
                      } else if (['http', 'https'].contains(uri.scheme)) {
                        openStorageLink(uri.toString());
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AssistantImageThumb extends StatelessWidget {
  const AssistantImageThumb({super.key, required this.data, this.size = 56});
  final String data;
  final double size;
  @override
  Widget build(BuildContext context) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(data.split(',').last),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: const Icon(LucideIcons.imageOff, size: 16),
          ),
        ),
      );
    } on FormatException {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(LucideIcons.imageOff, size: 16),
      );
    }
  }
}

class AssistantWebComposer extends StatelessWidget {
  const AssistantWebComposer({
    super.key,
    required this.input,
    required this.focus,
    required this.enabled,
    required this.sending,
    required this.listening,
    required this.picking,
    required this.images,
    required this.onSend,
    required this.onVoice,
    required this.onAttach,
    required this.onRemove,
  });
  final TextEditingController input;
  final FocusNode focus;
  final bool enabled, sending, listening, picking;
  final List<String> images;
  final VoidCallback onSend, onVoice, onAttach;
  final ValueChanged<int> onRemove;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < images.length; i++)
                  Stack(
                    children: [
                      AssistantImageThumb(data: images[i]),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: enabled ? () => onRemove(i) : null,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _AiColors.ink.withValues(alpha: .8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                key: const Key('assistant-input'),
                controller: input,
                focusNode: focus,
                minLines: MediaQuery.viewInsetsOf(context).bottom > 0 ? 1 : 2,
                maxLines: 5,
                enabled: enabled,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: _AiColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Опишите задачу для агента…'
                      : 'Сначала выберите рабочее пространство',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: _AiColors.muted,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('assistant-attach'),
                      tooltip: 'Прикрепить изображение',
                      onPressed: enabled && !picking ? onAttach : null,
                      icon: picking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              LucideIcons.paperclip,
                              size: 16,
                              color: _AiColors.muted,
                            ),
                    ),
                    IconButton(
                      key: const Key('assistant-microphone'),
                      tooltip: listening
                          ? 'Остановить запись'
                          : 'Задать вопрос голосом',
                      onPressed: enabled ? onVoice : null,
                      icon: Icon(
                        listening ? LucideIcons.square : LucideIcons.mic,
                        size: 16,
                        color: listening ? AppColors.accent : _AiColors.muted,
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: input,
                      builder: (context, value, _) => SizedBox(
                        width: 32,
                        height: 32,
                        child: FilledButton(
                          key: const Key('assistant-send'),
                          onPressed:
                              enabled &&
                                  !picking &&
                                  (value.text.trim().isNotEmpty ||
                                      images.isNotEmpty)
                              ? onSend
                              : null,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: sending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.send, size: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.shieldCheck, size: 12, color: _AiColors.muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Создание задач требует подтверждения. Изменения своих задач сохраняются сразу.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: _AiColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

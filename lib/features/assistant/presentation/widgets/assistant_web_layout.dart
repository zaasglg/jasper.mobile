import 'package:forui/forui.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../../domain/entities/assistant_attachment.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../storage/presentation/storage_file_screen.dart';
import '../../domain/entities/assistant_message_model.dart';

class AssistantWebHeader extends StatelessWidget {
  const AssistantWebHeader({
    super.key,
    required this.workspaceName,
    required this.onStopVoice,
    required this.onVoiceHelp,
    this.onHistory,
    this.onNewConversation,
  });
  final String workspaceName;
  final VoidCallback onStopVoice, onVoiceHelp;
  final VoidCallback? onHistory, onNewConversation;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/JBee.svg',
                        colorFilter: ColorFilter.mode(
                          colors.accent,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ai',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(context, 'AI-агент · задачи и проекты'),
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    FTheme(
                      data: Theme.of(context).brightness == Brightness.dark
                          ? FTheme.neutral.dark.touch
                          : FTheme.neutral.light.touch,
                      child: FPopoverMenu(
                        menuAnchor: Alignment.topRight,
                        childAnchor: Alignment.bottomRight,
                        menuBuilder: (context, controller, _) => [
                          FItemGroup(
                            children: [
                              FItem(
                                prefix: const Icon(
                                  LucideIcons.volumeX,
                                  size: 16,
                                ),
                                title: Text(
                                  tr(context, 'Остановить озвучивание'),
                                ),
                                onPress: () {
                                  controller.hide();
                                  onStopVoice();
                                },
                              ),
                              FItem(
                                prefix: const Icon(LucideIcons.mic, size: 16),
                                title: Text(tr(context, 'Голосовой вызов')),
                                onPress: () {
                                  controller.hide();
                                  onVoiceHelp();
                                },
                              ),
                            ],
                          ),
                        ],
                        builder: (context, controller, _) => IconButton(
                          tooltip: tr(context, 'Действия помощника'),
                          onPressed: controller.toggle,
                          icon: Icon(
                            LucideIcons.ellipsis,
                            size: 20,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Закрыть'),
                      onPressed: () {
                        if (context.canPop()) context.pop();
                      },
                      icon: Icon(LucideIcons.x, size: 20, color: colors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      LucideIcons.folderKanban,
                      size: 14,
                      color: colors.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'Контекст'),
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        workspaceName.isEmpty
                            ? tr(context, 'Рабочее пространство не выбрано')
                            : workspaceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.ink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: tr(context, 'История диалогов'),
                      onPressed: onHistory,
                      icon: const Icon(LucideIcons.panelLeft, size: 18),
                      color: colors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tr(context, 'Новый чат'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Новый диалог'),
                      onPressed: onNewConversation,
                      icon: const Icon(LucideIcons.plus, size: 18),
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 0,
                start: 16,
                child: Container(width: 48, height: 2, color: colors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
        hasWorkspace
            ? tr(context, 'Что поручим агенту?')
            : tr(context, 'Выберите рабочее пространство'),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -.35,
          height: 1.3,
          color: AppColors.of(context).ink,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        hasWorkspace
            ? tr(
                context,
                'Найду нужные данные, покажу задачи и сроки, подготовлю новую задачу или изменения существующей.',
              )
            : tr(
                context,
                'Выберите пространство в боковом меню — тогда агент сможет работать с его задачами, проектами и сообщениями.',
              ),
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: AppColors.of(context).muted,
        ),
      ),
      if (hasWorkspace) ...[
        const SizedBox(height: 28),
        Text(
          tr(context, 'Начните с поручения'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.of(context).muted,
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
              foregroundColor: AppColors.of(context).ink,
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.arrowUpRight,
                  size: 16,
                  color: AppColors.of(context).muted,
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
            Text(
              message.cancelled
                  ? tr(context, 'Вы · ответ остановлен')
                  : tr(context, 'Вы'),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.of(context).muted,
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset(
                    'assets/images/JBee.svg',
                    colorFilter: Theme.of(context).brightness == Brightness.dark
                        ? ColorFilter.mode(
                            AppColors.of(context).accent,
                            BlendMode.srcIn,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ai',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).ink,
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
                    color: AppColors.of(context).accent.withValues(alpha: .1),
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
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final file in message.attachments)
                          AssistantFileTile(file: file),
                      ],
                    ),
                  ),
                if (message.attachmentMessage?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      message.attachmentMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.of(context).muted,
                      ),
                    ),
                  ),
                if (user && message.content.isNotEmpty)
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.of(context).ink,
                    ),
                  )
                else if (!user && message.content.isNotEmpty)
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: TextStyle(
                            fontSize: 14,
                            height: 1.65,
                            color: AppColors.of(context).ink,
                          ),
                          h1: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          h2: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          h3: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          a: TextStyle(color: AppColors.of(context).accent),
                          blockSpacing: 8,
                          codeblockDecoration: BoxDecoration(
                            color: AppColors.of(context).subtleSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tableBorder: TableBorder.all(
                            color: AppColors.of(context).border,
                          ),
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
            child: Icon(LucideIcons.imageOff, size: 16),
          ),
        ),
      );
    } on FormatException {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(LucideIcons.imageOff, size: 16),
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
    required this.attachments,
    required this.onSend,
    required this.onVoice,
    required this.onAttach,
    required this.onRemove,
    this.onDayPlan,
  });
  final TextEditingController input;
  final FocusNode focus;
  final bool enabled, sending, listening, picking;
  final List<AssistantAttachment> attachments;
  final VoidCallback onSend, onVoice, onAttach;
  final ValueChanged<int> onRemove;
  final VoidCallback? onDayPlan;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: BoxDecoration(
      color: AppColors.of(context).canvas,
      border: Border(top: BorderSide(color: AppColors.of(context).border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < attachments.length; i++)
                  AssistantFileTile(
                    file: attachments[i],
                    onRemove: enabled ? () => onRemove(i) : null,
                  ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.of(context).border),
            color: AppColors.of(context).subtleSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TextField(
                key: const Key('assistant-input'),
                controller: input,
                focusNode: focus,
                minLines: 1,
                maxLines: 5,
                enabled: enabled,
                cursorColor: AppColors.of(context).accent,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.of(context).ink,
                ),
                decoration: InputDecoration(
                  hintText: enabled
                      ? tr(context, 'Опишите задачу для агента…')
                      : tr(context, 'Сначала выберите рабочее пространство'),
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.of(context).muted,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                      tooltip: tr(
                        context,
                        'Прикрепить файл (до 3 файлов по 8 МБ)',
                      ),
                      onPressed: enabled && !picking ? onAttach : null,
                      icon: picking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              LucideIcons.paperclip,
                              size: 20,
                              color: AppColors.of(context).muted,
                            ),
                    ),
                    IconButton(
                      key: const Key('assistant-microphone'),
                      tooltip: listening
                          ? tr(context, 'Остановить запись')
                          : tr(context, 'Задать вопрос голосом'),
                      onPressed: enabled ? onVoice : null,
                      icon: Icon(
                        listening ? LucideIcons.square : LucideIcons.mic,
                        size: 20,
                        color: listening
                            ? AppColors.of(context).accent
                            : AppColors.of(context).muted,
                      ),
                    ),
                    if (onDayPlan != null)
                      IconButton(
                        key: const Key('assistant-ai-day-plan'),
                        tooltip: tr(context, 'План дня через AI'),
                        onPressed: enabled && !listening && !picking
                            ? onDayPlan
                            : null,
                        icon: const Icon(LucideIcons.calendarDays, size: 20),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: AppColors.of(context).muted,
                        ),
                      ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: input,
                      builder: (context, value, _) => SizedBox(
                        width: 44,
                        height: 44,
                        child: FilledButton(
                          key: const Key('assistant-send'),
                          onPressed:
                              enabled &&
                                  !picking &&
                                  (value.text.trim().isNotEmpty ||
                                      attachments.isNotEmpty)
                              ? onSend
                              : null,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.of(context).accent,
                            foregroundColor: AppColors.of(context).onAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                              : Icon(LucideIcons.arrowUp, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.shieldCheck,
              size: 14,
              color: AppColors.of(context).muted,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(context, 'Создание — с подтверждением. Изменения — сразу.'),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.of(context).muted,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class AssistantFileTile extends StatelessWidget {
  const AssistantFileTile({super.key, required this.file, this.onRemove});
  final AssistantAttachment file;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final report = file.dataUrl == null;
    final unsupported = file.status == 'unsupported';
    final label = !report
        ? (file.size < 1024 * 1024
              ? '${(file.size / 1024).ceil()} КБ'
              : '${(file.size / (1024 * 1024)).toStringAsFixed(1)} МБ')
        : unsupported
        ? 'Не прочитан'
        : file.status == 'analyzed'
        ? file.truncated
              ? 'Прочитан частично'
              : file.analysisMode == 'vision'
              ? 'Распознано изображение'
              : file.analysisMode == 'text'
              ? 'Прочитан текст'
              : 'Файл обработан'
        : 'Статус чтения неизвестен';
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (file.isImage)
            AssistantImageThumb(data: file.dataUrl!, size: 32)
          else
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                unsupported || file.truncated
                    ? LucideIcons.triangleAlert
                    : LucideIcons.file,
                size: 20,
                color: unsupported
                    ? AppColors.of(context).error
                    : AppColors.of(context).accent,
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.of(context).muted,
                  ),
                ),
                if (file.reason?.isNotEmpty == true)
                  Text(
                    file.reason!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.of(context).muted,
                    ),
                  ),
                if (file.truncated)
                  Text(
                    tr(context, 'Обработана только часть содержимого.'),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.of(context).muted,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: tr(context, "Убрать {p0}", {'p0': file.name}),
              onPressed: onRemove,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              icon: Icon(LucideIcons.x, size: 16),
            ),
        ],
      ),
    );
  }
}

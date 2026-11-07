import '../../../../core/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/app_action_menu.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/conversation_cubit.dart';
import 'message_interactions.dart';

Future<void> showMessageActions(
  BuildContext context,
  ChatMessageModel message,
  bool isMine,
) async {
  final cubit = context.read<ConversationCubit>();
  final action = await showAppActionMenu<String>(
    context,
    title: 'Сообщение',
    groups: [
      [
        const AppMenuAction(
          value: 'reply',
          label: 'Ответить',
          icon: LucideIcons.reply,
        ),
        const AppMenuAction(
          value: 'forward',
          label: 'Переслать',
          icon: LucideIcons.forward,
        ),
        const AppMenuAction(
          value: 'react',
          label: 'Реакция',
          icon: LucideIcons.smile,
        ),
        AppMenuAction(
          value: 'pin',
          label: message.pinned ? 'Открепить' : 'Закрепить',
          icon: LucideIcons.pin,
        ),
        AppMenuAction(
          value: 'favorite',
          label: message.favorited
              ? 'Убрать из сохранённого'
              : 'Сохранить сообщение',
          icon: LucideIcons.bookmark,
        ),
        const AppMenuAction(
          value: 'copy',
          label: 'Копировать текст',
          icon: LucideIcons.copy,
        ),
        if (isMine &&
            message.kind == ChatMessageKind.text &&
            message.attachmentDataUrl == null)
          const AppMenuAction(
            value: 'edit',
            label: 'Редактировать',
            icon: LucideIcons.pencil,
          ),
      ],
      if (isMine)
        [
          const AppMenuAction(
            value: 'delete',
            label: 'Удалить сообщение',
            icon: LucideIcons.trash2,
            destructive: true,
          ),
        ],
    ],
  );
  if (action == null || !context.mounted || cubit.isClosed) return;
  if (action == 'reply') {
    cubit.selectReply(message);
    return;
  }
  if (action == 'forward') {
    await showForwardMessage(context, message);
    return;
  }
  if (action == 'react') {
    await showMessageReactions(context, message);
    return;
  }
  if (action == 'pin') {
    await cubit.interact(message.id);
    return;
  }
  if (action == 'copy') {
    await Clipboard.setData(ClipboardData(text: message.text));
    return;
  }
  if (action == 'delete' &&
      !await showAppConfirmation(
        context,
        'Удалить сообщение?',
        'Это действие нельзя отменить.',
        confirmLabel: 'Удалить',
        destructive: true,
      )) {
    return;
  }
  if (!context.mounted || cubit.isClosed) return;
  if (action == 'edit') {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _MessageEditor(
        message: message,
        onSave: (text) => cubit.messageAction(message.id, 'edit', text: text),
      ),
    );
  } else {
    await cubit.messageAction(message.id, action);
  }
}

class _MessageEditor extends StatefulWidget {
  const _MessageEditor({required this.message, required this.onSave});
  final ChatMessageModel message;
  final Future<bool> Function(String) onSave;
  @override
  State<_MessageEditor> createState() => _MessageEditorState();
}

class _MessageEditorState extends State<_MessageEditor> {
  late final _text = TextEditingController(
    text: widget.message.quote?.body ?? widget.message.text,
  );
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDialog(
      title: const Text('Изменить сообщение'),
      content: AppFormSurface(
        child: TextField(
          controller: _text,
          enabled: !_saving,
          minLines: 2,
          maxLines: 8,
          decoration: InputDecoration(errorText: _error),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  if (_text.text.trim().isEmpty) {
                    setState(() => _error = 'Введите текст');
                    return;
                  }
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  final quote = widget.message.quote;
                  final value = quote == null
                      ? _text.text
                      : '↩ @${quote.author}: «${quote.excerpt}»\n\n${_text.text}';
                  final success = await widget.onSave(value);
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _saving = false;
                      _error = 'Не удалось сохранить сообщение';
                    });
                  }
                },
          child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
        ),
      ],
    ),
  );
}

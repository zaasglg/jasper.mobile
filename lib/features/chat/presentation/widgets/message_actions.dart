import 'package:jospar/core/localization/app_translations.dart';
import 'reaction_emoji.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/chat_repository.dart';
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
  FocusManager.instance.primaryFocus?.unfocus();
  final box = context.findRenderObject();
  final anchor = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final groups = [
    [
      AppMenuAction(
        value: 'reply',
        label: tr(context, 'Ответить'),
        icon: LucideIcons.reply,
      ),
      AppMenuAction(
        enabled: message.canForward,
        value: 'forward',
        label: tr(context, 'Переслать'),
        icon: LucideIcons.forward,
      ),
      AppMenuAction(
        value: 'pin',
        label: message.pinned
            ? tr(context, 'Открепить')
            : tr(context, 'Закрепить'),
        icon: LucideIcons.pin,
      ),
      AppMenuAction(
        value: 'favorite',
        label: message.favorited
            ? tr(context, 'Убрать из сохранённого')
            : tr(context, 'Сохранить сообщение'),
        icon: LucideIcons.bookmark,
      ),
      AppMenuAction(
        enabled: message.canCopyText,
        value: 'copy',
        label: tr(context, 'Копировать текст'),
        icon: LucideIcons.copy,
      ),
      if (isMine && message.canEditText)
        AppMenuAction(
          value: 'edit',
          label: tr(context, 'Редактировать'),
          icon: LucideIcons.pencil,
        ),
    ],
    if (isMine)
      [
        AppMenuAction(
          value: 'delete',
          label: tr(context, 'Удалить сообщение'),
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
  ];
  final action = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .22),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    pageBuilder: (overlayContext, _, _) => _MessageActionsPopover(
      message: message,
      groups: groups,
      isMine: isMine,
      anchor: anchor,
      canReact: cubit.repository is ChatInteractionRepository,
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  if (action == null || !context.mounted || cubit.isClosed) return;
  if (action.startsWith('reaction:')) {
    await cubit.interact(
      message.id,
      emoji: action.substring('reaction:'.length),
    );
    return;
  }
  if (action == 'reply') {
    cubit.selectReply(message);
    return;
  }
  if (action == 'forward' && message.canForward) {
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
  if (action == 'copy' && message.canCopyText) {
    await Clipboard.setData(ClipboardData(text: message.text));
    return;
  }
  if (action == 'delete' &&
      !await showAppConfirmation(
        context,
        tr(context, 'Удалить сообщение?'),
        tr(context, 'Это действие нельзя отменить.'),
        confirmLabel: 'Удалить',
        destructive: true,
      )) {
    return;
  }
  if (!context.mounted || cubit.isClosed) return;
  if (action == 'edit' && message.canEditText) {
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

class _MessageActionsPopover extends StatelessWidget {
  const _MessageActionsPopover({
    required this.message,
    required this.groups,
    required this.isMine,
    required this.anchor,
    required this.canReact,
  });
  final ChatMessageModel message;
  final List<List<AppMenuAction<String>>> groups;
  final bool isMine, canReact;
  final Rect? anchor;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kk = Localizations.localeOf(context).languageCode == 'kk';
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(340.0, constraints.maxWidth - 24);
          final desiredHeight =
              60.0 +
              groups.fold<int>(0, (sum, group) => sum + group.length) * 48 +
              groups.length -
              1;
          final height = math.min(
            math.min(440.0, desiredHeight),
            math.max(
              80.0,
              constraints.maxHeight -
                  MediaQuery.viewInsetsOf(context).bottom -
                  24,
            ),
          );
          final anchorY =
              (anchor?.top ?? constraints.maxHeight / 2) -
              MediaQuery.paddingOf(context).top;
          final top = (anchorY - 58).clamp(
            8.0,
            math.max(
              8.0,
              constraints.maxHeight -
                  MediaQuery.viewInsetsOf(context).bottom -
                  height -
                  8,
            ),
          );
          return Stack(
            children: [
              Positioned(
                top: top.toDouble(),
                left: isMine ? null : 12,
                right: isMine ? 12 : null,
                width: width,
                child: SizedBox(
                  height: height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        key: const Key('message-quick-reactions'),
                        color: colors.surface,
                        elevation: 6,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(30),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              for (final emoji in const [
                                '👍',
                                '❤️',
                                '😂',
                                '😮',
                                '😢',
                                '🙏',
                              ])
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    label: kk
                                        ? 'Реакция қою: $emoji'
                                        : tr(
                                            context,
                                            "Поставить реакцию {p0}",
                                            {'p0': emoji},
                                          ),
                                    selected: message.reactions.any(
                                      (r) => r.emoji == emoji && r.reacted,
                                    ),
                                    child: InkWell(
                                      key: ValueKey('message-react-$emoji'),
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: canReact
                                          ? () => Navigator.pop(
                                              context,
                                              'reaction:$emoji',
                                            )
                                          : null,
                                      child: Container(
                                        height: 44,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              message.reactions.any(
                                                (r) =>
                                                    r.emoji == emoji &&
                                                    r.reacted,
                                              )
                                              ? AppColors.accent.withValues(
                                                  alpha: .13,
                                                )
                                              : null,
                                        ),
                                        child: ReactionEmoji(emoji, size: 32),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: IconButton(
                                  key: const Key('message-more-reactions'),
                                  tooltip: tr(context, 'Другие реакции'),
                                  onPressed: canReact
                                      ? () => Navigator.pop(context, 'react')
                                      : null,
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    LucideIcons.plus,
                                    size: 23,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Align(
                          alignment: isMine
                              ? Alignment.topRight
                              : Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Material(
                              color: colors.surface,
                              elevation: 6,
                              shadowColor: Colors.black26,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      var group = 0;
                                      group < groups.length;
                                      group++
                                    ) ...[
                                      if (group > 0)
                                        Divider(
                                          height: 1,
                                          color: colors.outlineVariant,
                                        ),
                                      for (final action in groups[group])
                                        ListTile(
                                          enabled: action.enabled,
                                          dense: true,
                                          minTileHeight: 46,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                              ),
                                          title: Text(
                                            action.label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: !action.enabled
                                                  ? colors.onSurface.withValues(
                                                      alpha: .3,
                                                    )
                                                  : action.destructive
                                                  ? colors.error
                                                  : colors.onSurface,
                                            ),
                                          ),
                                          trailing: Icon(
                                            action.icon,
                                            size: 19,
                                            color: !action.enabled
                                                ? colors.onSurface.withValues(
                                                    alpha: .3,
                                                  )
                                                : action.destructive
                                                ? colors.error
                                                : colors.onSurfaceVariant,
                                          ),
                                          onTap: action.enabled
                                              ? () => Navigator.pop(
                                                  context,
                                                  action.value,
                                                )
                                              : null,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
      title: Text(tr(context, 'Изменить сообщение')),
      content: AppFormSurface(
        child: TextField(
          controller: _text,
          enabled: !_saving,
          minLines: 2,
          maxLines: 8,
          decoration: InputDecoration(errorText: trn(context, _error)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(tr(context, 'Отмена')),
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
          child: Text(
            _saving ? tr(context, 'Сохранение…') : tr(context, 'Сохранить'),
          ),
        ),
      ],
    ),
  );
}

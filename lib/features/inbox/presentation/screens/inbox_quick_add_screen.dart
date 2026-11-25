import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../cubit/inbox_cubit.dart';
import '../cubit/inbox_state.dart';

class InboxQuickAddScreen extends StatefulWidget {
  const InboxQuickAddScreen({super.key, this.overlay = false, this.onClose});
  final bool overlay;
  final VoidCallback? onClose;

  @override
  State<InboxQuickAddScreen> createState() => _InboxQuickAddScreenState();
}

class _InboxQuickAddScreenState extends State<InboxQuickAddScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || context.read<InboxCubit>().state.isCreating) return;

    final created = await context.read<InboxCubit>().create(title);
    if (!mounted) return;

    if (!created) {
      final message = context.read<InboxCubit>().state.creationErrorMessage;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(message ?? 'Не удалось создать задачу.'),
          ),
        );
      _focusNode.requestFocus();
      return;
    }

    if (widget.overlay) {
      _focusNode.unfocus();
      widget.onClose?.call();
      return;
    }
    _controller.clear();
    setState(() {});
    _focusNode.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.success,
          content: Text(tr(context, 'Задача добавлена в Инбокс')),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.overlay
          ? Colors.black54
          : AppColors.of(context).canvas,
      body: SafeArea(
        child: Align(
          alignment: widget.overlay ? Alignment.bottomCenter : Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: BlocBuilder<InboxCubit, InboxState>(
                buildWhen: (previous, current) =>
                    previous.isCreating != current.isCreating,
                builder: (context, state) {
                  final canSubmit =
                      _controller.text.trim().isNotEmpty && !state.isCreating;
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.mdLg),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).canvas,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.of(context).border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (widget.overlay)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: tr(context, 'Закрыть'),
                              onPressed: state.isCreating
                                  ? null
                                  : widget.onClose,
                              icon: const Icon(LucideIcons.x),
                            ),
                          ),
                        Row(
                          children: <Widget>[
                            Container(
                              width: AppSpacing.touchTarget,
                              height: AppSpacing.touchTarget,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.inbox,
                                color: AppColors.accent,
                                size: AppSpacing.lg,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.smMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    tr(context, 'Добавить в Инбокс'),
                                    style: AppTypography.title(context),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    tr(
                                      context,
                                      'Запишите сейчас, разберите позже',
                                    ),
                                    style: AppTypography.caption(context)
                                        ?.copyWith(
                                          color: AppColors.of(context).muted,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.mdLg),
                        TextField(
                          key: const Key('inbox-quick-add-input'),
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          enabled: !state.isCreating,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => canSubmit ? _submit() : null,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: tr(context, 'Что нужно не забыть?'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('inbox-quick-add-submit'),
                            onPressed: canSubmit ? _submit : null,
                            icon: state.isCreating
                                ? const SizedBox.square(
                                    dimension: AppIconSizes.standard,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onAccent,
                                    ),
                                  )
                                : const Icon(LucideIcons.plus),
                            label: Text(
                              state.isCreating
                                  ? tr(context, 'Добавляем…')
                                  : tr(context, 'Добавить'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

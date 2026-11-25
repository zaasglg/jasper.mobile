import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_ui_tokens.dart';

import '../../../inbox/presentation/cubit/inbox_cubit.dart';
import '../../../inbox/presentation/cubit/inbox_state.dart';

class DashboardInboxComposer extends StatefulWidget {
  const DashboardInboxComposer({super.key});

  @override
  State<DashboardInboxComposer> createState() => _DashboardInboxComposerState();
}

class _DashboardInboxComposerState extends State<DashboardInboxComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    if (context.read<InboxCubit>().state.isCreating) return;
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final created = await context.read<InboxCubit>().create(title);
    if (!mounted) return;

    if (created) {
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
      return;
    }

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
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxCubit, InboxState>(
      buildWhen: (previous, current) =>
          previous.isCreating != current.isCreating,
      builder: (context, state) {
        final colors = Theme.of(context).colorScheme;
        final canSubmit =
            _controller.text.trim().isNotEmpty && !state.isCreating;

        return Container(
          key: const Key('dashboard-inbox-composer'),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: AppSpacing.touchTarget,
                    height: AppSpacing.touchTarget,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.inbox,
                      size: AppSpacing.lg,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tr(context, 'Быстро в Инбокс'),
                          style: AppTypography.body(context)?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          tr(context, 'Запишите сейчас, разберите позже'),
                          style: AppTypography.caption(
                            context,
                          )?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppColors.of(context).subtleSurface
                      : colors.surfaceContainerLow,
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: .5),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('dashboard-inbox-input'),
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !state.isCreating,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => canSubmit ? _createTask() : null,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        style: AppTypography.body(context),
                        decoration: InputDecoration(
                          hintText: tr(context, 'Что нужно не забыть?'),
                          filled: false,
                          contentPadding: const EdgeInsets.all(AppSpacing.sm),
                          hintStyle: AppTypography.body(
                            context,
                          )?.copyWith(color: colors.onSurfaceVariant),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('dashboard-inbox-add'),
                      tooltip: tr(context, 'Добавить в Инбокс'),
                      onPressed: canSubmit ? _createTask : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(AppSpacing.touchTarget),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        backgroundColor: colors.primary,
                        disabledBackgroundColor: colors.onSurface.withValues(
                          alpha: .05,
                        ),
                        foregroundColor: colors.onPrimary,
                        disabledForegroundColor: colors.onSurfaceVariant,
                      ),
                      icon: state.isCreating
                          ? SizedBox.square(
                              dimension: AppIconSizes.standard,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          : const Icon(LucideIcons.plus, size: AppSpacing.lg),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

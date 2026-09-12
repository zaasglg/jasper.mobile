import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
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
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
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
          const SnackBar(content: Text('Задача добавлена в Инбокс')),
        );
      return;
    }

    final message = context.read<InboxCubit>().state.creationErrorMessage;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message ?? 'Не удалось создать задачу.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxCubit, InboxState>(
      buildWhen: (previous, current) =>
          previous.isCreating != current.isCreating,
      builder: (context, state) {
        final canSubmit =
            _controller.text.trim().isNotEmpty && !state.isCreating;

        return Container(
          key: const Key('dashboard-inbox-composer'),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inbox_rounded,
                      size: 19,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Быстро в Инбокс',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Запишите сейчас, разберите позже',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(13, 3, 4, 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
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
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Что нужно не забыть?',
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('dashboard-inbox-add'),
                      tooltip: 'Добавить в Инбокс',
                      onPressed: canSubmit ? _createTask : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(40),
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor: AppColors.skeleton,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppColors.muted,
                      ),
                      icon: state.isCreating
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 23),
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

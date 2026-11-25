import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../domain/entities/column_copy_result.dart';
import '../../domain/utils/kanban_utils.dart';
import '../cubit/column_copy_cubit.dart';

class ColumnCopySheet extends StatefulWidget {
  const ColumnCopySheet({super.key});

  @override
  State<ColumnCopySheet> createState() => _ColumnCopySheetState();
}

class _ColumnCopySheetState extends State<ColumnCopySheet> {
  final _form = GlobalKey<FormState>();
  TextEditingController? _name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cubit = context.read<ColumnCopyCubit>();
    _name ??= TextEditingController(
      text: nextColumnCopyName(
        cubit.column.name,
        cubit.board.state.columns.map((column) => column.name),
        copyLabel: tr(context, 'Копия'),
      ),
    );
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      context.read<ColumnCopyCubit>().submit(_name!.text);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ColumnCopyCubit, ColumnCopyResult>(
    listener: (context, state) {
      if (state.status == ColumnCopyStatus.success) {
        Navigator.of(context).pop(state.columnId);
      }
    },
    builder: (context, state) {
      final busy = state.status == ColumnCopyStatus.submitting;
      final refreshOnly = {
        ColumnCopyStatus.uncertain,
        ColumnCopyStatus.stale,
        ColumnCopyStatus.forbidden,
      }.contains(state.status);
      return AppFormSurface(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(context, 'Копировать колонку'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        context,
                        'Будет создана новая колонка с копиями задач. Исходная колонка останется без изменений',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Название новой колонки'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? tr(context, 'Введите название новой колонки')
                          : null,
                      onFieldSubmitted: (_) {
                        if (!busy && !refreshOnly) _submit();
                      },
                    ),
                    if (state.message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        tr(context, state.message!),
                        key: const ValueKey('column-copy-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : refreshOnly
                          ? context.read<ColumnCopyCubit>().refresh
                          : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              tr(
                                context,
                                refreshOnly ? 'Обновить доску' : 'Копировать',
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr(context, 'Отмена')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

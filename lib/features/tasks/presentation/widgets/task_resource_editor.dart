import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'task_extras_sheet.dart' show showResourceCalculator;
import '../../data/models/task_detail_model.dart';
import '../cubit/task_details_cubit.dart';

enum ResourceEditField { all, identity, plan, fact }

String _formatValue(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

double? _parseValue(String text) {
  final value = text.trim().isEmpty
      ? 0.0
      : double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

Future<void> showResourceEditor(
  BuildContext context,
  TaskDetailsCubit cubit, {
  TaskResourceModel? resource,
  ResourceEditField field = ResourceEditField.all,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      TaskResourceEditor(cubit: cubit, resource: resource, field: field),
);

class TaskResourceEditor extends StatefulWidget {
  const TaskResourceEditor({
    required this.cubit,
    this.resource,
    this.field = ResourceEditField.all,
    super.key,
  });
  final TaskDetailsCubit cubit;
  final TaskResourceModel? resource;
  final ResourceEditField field;
  @override
  State<TaskResourceEditor> createState() => _TaskResourceEditorState();
}

class _TaskResourceEditorState extends State<TaskResourceEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.resource?.name ?? '');
  late final _plan = TextEditingController(
    text: _formatValue(widget.resource?.planValue ?? 0),
  );
  late final _fact = TextEditingController(
    text: _formatValue(widget.resource?.factValue ?? 0),
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _plan, _fact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final value = (widget.resource ?? const TaskResourceModel(id: '', name: ''))
        .copyWith(
          name: _name.text.trim(),
          planValue: _parseValue(_plan.text)!,
          factValue: _parseValue(_fact.text)!,
        );
    final previous = widget.resource;
    final changes = <String, Object?>{
      if (previous?.name != value.name) 'name': value.name,
      if (previous?.planValue != value.planValue)
        'planValue': value.planValue.toStringAsFixed(4),
      if (previous?.factValue != value.factValue)
        'factValue': value.factValue.toStringAsFixed(4),
    };
    final ok = previous == null
        ? await widget.cubit.saveResource(value, create: true)
        : changes.isEmpty ||
              await widget.cubit.patchResource(value.id, changes);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error =
            widget.cubit.state.actionErrorMessage ??
            'Не удалось сохранить ресурс. Повторите попытку.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity =
        widget.field == ResourceEditField.all ||
        widget.field == ResourceEditField.identity;
    final preview = TaskResourceModel(
      id: '',
      name: '',
      planValue: _parseValue(_plan.text) ?? 0,
      factValue: _parseValue(_fact.text) ?? 0,
    );
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.resource == null
                        ? tr(context, 'Новый ресурс')
                        : tr(context, 'Изменить ресурс'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (identity) ...[
                    TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: tr(context, 'Название'),
                        helperText: tr(
                          context,
                          'Например: бетон, бюджет, работа дизайнера',
                        ),
                        helperMaxLines: 2,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? tr(context, 'Введите название')
                          : null,
                    ),
                  ],
                  for (final entry in [
                    ('План', _plan, ResourceEditField.plan),
                    ('Факт', _fact, ResourceEditField.fact),
                  ])
                    if (widget.field == ResourceEditField.all ||
                        widget.field == entry.$3)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextFormField(
                          controller: entry.$2,
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: entry.$1,
                            suffixIcon: widget.resource != null
                                ? null
                                : IconButton(
                                    tooltip: tr(context, 'Калькулятор'),
                                    icon: const Icon(Icons.calculate_outlined),
                                    onPressed: _busy
                                        ? null
                                        : () async {
                                            final value =
                                                await showResourceCalculator(
                                                  context,
                                                  _parseValue(entry.$2.text) ??
                                                      0,
                                                );
                                            if (!mounted || value == null) {
                                              return;
                                            }
                                            setState(
                                              () => entry.$2.text =
                                                  _formatValue(value),
                                            );
                                          },
                                  ),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n = _parseValue(v ?? '');
                            return n == null || !n.isFinite || n < 0
                                ? tr(context, 'Введите число от 0')
                                : !RegExp(
                                        r'^\d+(?:[.,]\d{1,4})?$',
                                      ).hasMatch((v ?? '').trim()) &&
                                      (v ?? '').trim().isNotEmpty
                                ? tr(context, 'Не более 4 знаков после запятой')
                                : null;
                          },
                        ),
                      ),
                  const SizedBox(height: 16),
                  Text(
                    preview.planValue > 0
                        ? tr(context, "Использовано: {p0}%{p1}", {
                            'p0': preview.percentage.round(),
                            'p1': preview.isOverBudget ? ' · Перерасход' : '',
                          })
                        : tr(context, 'Использовано: —'),
                    style: TextStyle(
                      color: preview.isOverBudget
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  if (preview.planValue == 0 && preview.factValue > 0)
                    Text(tr(context, 'Укажите план для расчёта процента')),
                  if (_error != null)
                    Text(
                      tr(context, _error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _busy
                          ? tr(context, 'Сохранение…')
                          : tr(context, 'Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

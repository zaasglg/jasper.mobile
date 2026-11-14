import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../data/models/task_detail_model.dart';
import '../cubit/task_details_cubit.dart';
import 'resource_server_tools.dart';

class TaskResourcePairs extends StatelessWidget {
  const TaskResourcePairs({required this.resources, super.key});
  final List<TaskResourceModel> resources;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskDetailsCubit>();
    final sorted = [...resources]..sort((a, b) => a.order.compareTo(b.order));
    if (sorted.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('Нет ресурсов. Нажмите «+», чтобы добавить.'),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i += 2)
          _Pair(resources: sorted.skip(i).take(2).toList(), cubit: cubit),
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.resources, required this.cubit});
  final List<TaskResourceModel> resources;
  final TaskDetailsCubit cubit;
  @override
  Widget build(BuildContext context) {
    final plan = resources.first.planValue;
    final fact = resources.length < 2 ? 0.0 : resources.last.factValue;
    final percentage = TaskResourceModel(
      id: '',
      name: '',
      planValue: plan,
      factValue: fact,
    ).percentage;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < resources.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Value(
                    resource: resources[i],
                    cubit: cubit,
                    isPlan: i == 0,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.smMd,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: percentage > 100
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  plan > 0 && resources.length == 2
                      ? 'Расход ${percentage.round()}%'
                      : 'Расход —',
                  style: AppTypography.caption(context)?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: percentage > 100
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'История группы ресурсов',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(AppSpacing.touchTarget),
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(LucideIcons.history, size: 16),
                onPressed: () =>
                    showResourcePairHistory(context, cubit, resources),
              ),
              IconButton(
                tooltip: 'Удалить строку ресурсов',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(AppSpacing.touchTarget),
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(LucideIcons.trash2, size: 16),
                onPressed: cubit.state.isSaving
                    ? null
                    : () async {
                        if (await showAppConfirmation(
                          context,
                          'Удалить строку ресурсов?',
                          'Ресурсы и история их изменений будут удалены.',
                          confirmLabel: 'Удалить',
                          destructive: true,
                        )) {
                          if (!cubit.isClosed) {
                            await cubit.deleteResourcePair(resources);
                          }
                        }
                      },
              ),
            ],
          ),
          Divider(
            height: AppSpacing.md,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .5),
          ),
        ],
      ),
    );
  }
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class _Value extends StatelessWidget {
  const _Value({
    required this.resource,
    required this.cubit,
    required this.isPlan,
  });
  final bool isPlan;
  final TaskResourceModel resource;
  final TaskDetailsCubit cubit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ResourceInlineField(
        key: ValueKey('${resource.id}-name'),
        resource: resource,
        isPlan: isPlan,
        cubit: cubit,
        editName: true,
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: ResourceInlineField(
                key: ValueKey('${resource.id}-value'),
                resource: resource,
                isPlan: isPlan,
                cubit: cubit,
              ),
            ),
            IconButton(
              tooltip: 'Калькулятор: ${resource.name}',
              onPressed: cubit.state.isSaving
                  ? null
                  : () => showServerResourceCalculator(
                      context,
                      cubit,
                      resource.id,
                      isPlan ? 'PLAN' : 'FACT',
                      isPlan ? resource.planValue : resource.factValue,
                    ),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSpacing.touchTarget),
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              icon: const Icon(LucideIcons.calculator, size: 16),
            ),
          ],
        ),
      ),
    ],
  );
}

class ResourceInlineField extends StatefulWidget {
  const ResourceInlineField({
    required this.resource,
    required this.cubit,
    this.editName = false,
    this.isPlan = true,
    super.key,
  });
  final TaskResourceModel resource;
  final TaskDetailsCubit cubit;
  final bool editName;
  final bool isPlan;
  @override
  State<ResourceInlineField> createState() => _ResourceInlineFieldState();
}

class _ResourceInlineFieldState extends State<ResourceInlineField> {
  late final _controller = TextEditingController(text: _saved);
  final _focus = FocusNode();
  bool _editing = false, _busy = false;
  String? _error;
  String get _saved => widget.editName
      ? widget.resource.name
      : _number(
          widget.isPlan ? widget.resource.planValue : widget.resource.factValue,
        );
  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus && _editing && !_busy) {
      _save();
    }
  }

  @override
  void didUpdateWidget(covariant ResourceInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && !_busy) _controller.text = _saved;
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _error = null;
      _controller.text = _saved;
    });
    _focus.unfocus();
  }

  Future<void> _save() async {
    if (!_editing || _busy) return;
    final text = _controller.text.trim();
    final normalized = text.replaceAll(',', '.');
    final value = normalized.isEmpty ? 0.0 : double.tryParse(normalized);
    if ((widget.editName && (text.isEmpty || text.length > 120)) ||
        (!widget.editName &&
            (value == null ||
                !value.isFinite ||
                value < 0 ||
                (normalized.isNotEmpty &&
                    !RegExp(r'^\d+(?:\.\d{1,4})?$').hasMatch(normalized))))) {
      setState(
        () => _error = widget.editName
            ? 'Название: 1–120 символов'
            : 'Число от 0, до 4 знаков после запятой',
      );
      return;
    }
    if (text == _saved) {
      _cancel();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.cubit.patchResource(
      widget.resource.id,
      widget.editName
          ? {'name': text}
          : {
              widget.isPlan ? 'planValue' : 'factValue': value!.toStringAsFixed(
                4,
              ),
            },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _editing = false;
        _controller.text = widget.editName ? text : _number(value!);
      } else {
        _error =
            widget.cubit.state.actionErrorMessage ?? 'Не удалось сохранить';
      }
    });
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event.logicalKey == LogicalKeyboardKey.escape && !_busy) {
        _cancel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      readOnly: _busy || (widget.cubit.state.isSaving && !_editing),
      onTap: () {
        if (!_busy) setState(() => _editing = true);
      },
      onChanged: (_) => setState(() {
        _editing = true;
        _error = null;
      }),
      onSubmitted: (_) => _save(),
      onTapOutside: (_) => _focus.unfocus(),
      textInputAction: TextInputAction.done,
      keyboardType: widget.editName
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      textAlign: widget.editName ? TextAlign.start : TextAlign.end,
      style: widget.editName
          ? AppTypography.body(context)?.copyWith(fontWeight: FontWeight.w600)
          : Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.smMd,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        errorText: _error,
        errorMaxLines: 4,
        suffixIcon: _busy
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.smMd),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : widget.editName
            ? Icon(
                LucideIcons.pencil,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    ),
  );
}

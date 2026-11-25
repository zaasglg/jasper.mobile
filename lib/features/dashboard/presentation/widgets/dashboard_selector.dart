import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

Future<T?> _select<T>(
  BuildContext context,
  String title,
  List<({T value, Widget label, bool enabled})> options,
  T? initial,
) {
  var selected = initial;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return CheckboxListTile(
                          key: ValueKey('dashboard-option-${option.value}'),
                          title: option.label,
                          value: selected == option.value,
                          selected: selected == option.value,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onChanged: option.enabled
                              ? (_) => update(() => selected = option.value)
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(context, selected),
                      child: Text(tr(context, 'Готово')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class DashboardSelector<T> extends StatelessWidget {
  const DashboardSelector({
    required this.itemBuilder,
    required this.onSelected,
    required this.child,
    this.tooltip,
    this.enabled = true,
    super.key,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T> onSelected;
  final Widget child;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? 'Выбрать',
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: !enabled
          ? null
          : () async {
              final entries = itemBuilder(
                context,
              ).whereType<PopupMenuItem<T>>().toList();
              final initial = entries
                  .whereType<CheckedPopupMenuItem<T>>()
                  .where((entry) => entry.checked)
                  .firstOrNull
                  ?.value;
              final result = await _select<T>(context, tooltip ?? 'Выбрать', [
                for (final entry in entries)
                  if (entry.value != null)
                    (
                      value: entry.value as T,
                      label: entry.child ?? const SizedBox(),
                      enabled: entry.enabled,
                    ),
              ], initial);
              if (context.mounted && result != null) onSelected(result);
            },
      child: child,
    ),
  );
}

class DashboardSelectorField<T> extends StatelessWidget {
  const DashboardSelectorField({
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    super.key,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onChanged == null
        ? null
        : () async {
            final value =
                await _select<T>(context, decoration.labelText ?? 'Выбрать', [
                  for (final item in items)
                    if (item.value != null)
                      (
                        value: item.value as T,
                        label: item.child,
                        enabled: item.enabled,
                      ),
                ], initialValue);
            if (context.mounted && value != null) onChanged!(value);
          },
    child: InputDecorator(
      decoration: decoration.copyWith(
        suffixIcon: const Icon(Icons.expand_more),
      ),
      child:
          items
              .where((item) => item.value == initialValue)
              .firstOrNull
              ?.child ??
          const SizedBox(),
    ),
  );
}

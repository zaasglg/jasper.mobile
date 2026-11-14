import '../theme/task_label_color.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../theme/app_ui_tokens.dart';

/// Shared preset palette with an expandable HSV picker and hexadecimal input.
class AppColorPicker extends StatefulWidget {
  const AppColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.extraColors = const [],
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final List<Color> extraColors;

  static const presets = <Color>[
    Color(0xFFE11D48),
    Color(0xFFEAB308),
    Color(0xFF16A34A),
    Color(0xFF2563EB),
    AppColors.accent,
  ];

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  late final _hex = TextEditingController(text: _hexValue);
  String get _hexValue =>
      '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  bool _expanded = false;
  double _hue = 0;

  Color get _color => taskLabelColor(widget.value);

  @override
  void initState() {
    super.initState();
    _hue = HSVColor.fromColor(_color).hue;
  }

  @override
  void didUpdateWidget(covariant AppColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _hex.value = TextEditingValue(
        text: _hexValue,
        selection: TextSelection.collapsed(offset: _hexValue.length),
      );
      final hsv = HSVColor.fromColor(_color);
      if (hsv.saturation > 0 && hsv.value > 0) _hue = hsv.hue;
    }
  }

  void _select(Color color) {
    widget.onChanged(
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    );
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_color);
    final custom = ![
      ...AppColorPicker.presets,
      ...widget.extraColors,
    ].contains(_color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final color in [
              ...AppColorPicker.presets,
              ...widget.extraColors,
            ])
              _ColorSwatch(
                color: color,
                selected: color == _color,
                label:
                    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                onTap: widget.enabled ? () => _select(color) : null,
              ),
            _ColorSwatch(
              selected: custom || _expanded,
              label: 'Другой цвет',
              onTap: widget.enabled
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.smMd),
          Container(
            padding: const EdgeInsets.all(AppSpacing.smMd),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const height = 180.0;
                    void update(Offset position) {
                      _select(
                        HSVColor.fromAHSV(
                          1,
                          _hue,
                          (position.dx / constraints.maxWidth).clamp(0, 1),
                          (1 - position.dy / height).clamp(0, 1),
                        ).toColor(),
                      );
                    }

                    return Semantics(
                      label: 'Насыщенность и яркость цвета',
                      child: GestureDetector(
                        onTapDown: widget.enabled
                            ? (event) => update(event.localPosition)
                            : null,
                        onPanStart: widget.enabled
                            ? (event) => update(event.localPosition)
                            : null,
                        onPanUpdate: widget.enabled
                            ? (event) => update(event.localPosition)
                            : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: SizedBox(
                            height: height,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          HSVColor.fromAHSV(
                                            1,
                                            _hue,
                                            1,
                                            1,
                                          ).toColor(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left:
                                      (hsv.saturation * constraints.maxWidth -
                                              10)
                                          .clamp(0, constraints.maxWidth - 20),
                                  top: ((1 - hsv.value) * height - 10).clamp(
                                    0,
                                    height - 20,
                                  ),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _color,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Color(0xFFFF00FF),
                        Colors.red,
                      ],
                    ),
                  ),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 24,
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: _hue,
                      min: 0,
                      max: 360,
                      semanticFormatterCallback: (value) =>
                          'Оттенок ${value.round()}°',
                      onChanged: widget.enabled
                          ? (value) {
                              setState(() => _hue = value);
                              _select(
                                HSVColor.fromAHSV(
                                  1,
                                  value,
                                  hsv.saturation,
                                  hsv.value,
                                ).toColor(),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.smMd),
                TextField(
                  key: const Key('color_hex_input'),
                  controller: _hex,
                  enabled: widget.enabled,
                  maxLength: 7,
                  decoration: const InputDecoration(
                    labelText: 'HEX',
                    hintText: '#6D5FE0',
                    counterText: '',
                  ),
                  onChanged: (value) {
                    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
                      widget.onChanged(value.toUpperCase());
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    this.color,
    required this.selected,
    required this.label,
    this.onTap,
  });
  final Color? color;
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
      ),
      icon: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: selected || color == null
                ? AppColors.ink
                : Colors.transparent,
            width: 3,
          ),
        ),
        alignment: Alignment.center,
        child: color == null
            ? Icon(
                LucideIcons.palette,
                color: selected ? AppColors.accent : AppColors.muted,
                size: 23,
              )
            : selected
            ? Icon(
                Icons.check_rounded,
                color:
                    ThemeData.estimateBrightnessForColor(color!) ==
                        Brightness.light
                    ? AppColors.ink
                    : AppColors.onAccent,
                size: 25,
              )
            : null,
      ),
    ),
  );
}

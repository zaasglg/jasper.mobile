import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

class PlannerTimeField extends StatelessWidget {
  const PlannerTimeField({
    super.key,
    required this.time,
    required this.onChanged,
  });
  final TimeOfDay time;
  final ValueChanged<TimeOfDay>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      label: tr(context, "Время начала, {p0}", {'p0': value}),
      child: Material(
        color: dark ? const Color(0xFF242424) : const Color(0xFFF7F7F7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: dark ? const Color(0xFF3C3C3C) : const Color(0xFFE5E5E5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChanged == null
              ? null
              : () async {
                  final result = await showPlannerTimePicker(context, time);
                  if (context.mounted && result != null) {
                    onChanged?.call(result);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.clock3,
                  size: 19,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(context, 'Время начала'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF303030) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onChanged == null
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronsUpDown,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<TimeOfDay?> showPlannerTimePicker(
  BuildContext context,
  TimeOfDay initial,
) {
  var draft = initial;
  final colors = Theme.of(context).colorScheme;
  final brightness = Theme.of(context).brightness;
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (sheetContext) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: (MediaQuery.sizeOf(sheetContext).height * .48).clamp(
          250.0,
          360.0,
        ),
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(
                        tr(context, 'Отмена'),
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tr(context, 'Время начала'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      key: const Key('planner-time-done'),
                      onPressed: () => Navigator.pop(sheetContext, draft),
                      child: Text(
                        tr(context, 'Готово'),
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: brightness,
                    primaryColor: AppColors.accent,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: GoogleFonts.inter(
                        fontSize: 22,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(
                      2000,
                      1,
                      1,
                      initial.hour,
                      initial.minute,
                    ),
                    onDateTimeChanged: (date) =>
                        draft = TimeOfDay.fromDateTime(date),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

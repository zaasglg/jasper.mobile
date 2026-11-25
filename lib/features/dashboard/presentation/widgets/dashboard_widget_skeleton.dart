import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Static placeholders also respect reduced-motion settings by design.
class DashboardWidgetSkeleton extends StatelessWidget {
  const DashboardWidgetSkeleton({
    this.showHeading = true,
    this.kind = '',
    super.key,
  });

  final bool showHeading;
  final String kind;

  Widget _bar(BuildContext context, double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.of(context).skeleton,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr(context, 'Загрузка виджета'),
    child: ExcludeSemantics(
      child: SingleChildScrollView(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHeading) ...[
                Row(
                  children: [
                    _bar(context, 22, 22),
                    const SizedBox(width: 12),
                    _bar(context, 128, 14),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (kind == 'resource' || kind == 'kpi-group')
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      for (var i = 0; i < 2; i++)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.of(context).skeleton,
                                  width: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    children: [
                      ClipOval(child: _bar(context, 32, 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(
                              widthFactor: i == 1 ? .65 : .8,
                              child: _bar(context, double.infinity, 12),
                            ),
                            const SizedBox(height: 9),
                            FractionallySizedBox(
                              widthFactor: .45,
                              child: _bar(context, double.infinity, 9),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

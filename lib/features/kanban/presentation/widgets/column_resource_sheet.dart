import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../domain/entities/resource_pair_total.dart';
import '../cubit/column_resource_cubit.dart';

class ColumnResourceSheet extends StatelessWidget {
  const ColumnResourceSheet({required this.columnName, super.key});
  final String columnName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppFormSurface(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.chartNoAxesCombined,
                    color: colors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(context, 'Ресурс'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(context, 'Закрыть'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'Колонка «{p0}»', {'p0': columnName}),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              BlocBuilder<ColumnResourceCubit, ColumnResourceState>(
                builder: (context, state) {
                  switch (state.status) {
                    case ColumnResourceStatus.loading:
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    case ColumnResourceStatus.failure:
                      return Column(
                        children: [
                          Text(
                            tr(context, state.message!),
                            style: TextStyle(color: colors.error),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: context.read<ColumnResourceCubit>().load,
                            child: Text(tr(context, 'Повторить')),
                          ),
                        ],
                      );
                    case ColumnResourceStatus.success:
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.pairs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                tr(context, 'Нет данных ресурса'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          for (final pair in state.pairs) ...[
                            ResourcePairBar(pair: pair),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            tr(context, '{p0} задач', {'p0': state.taskCount}),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResourcePairBar extends StatelessWidget {
  const ResourcePairBar({required this.pair, super.key});
  final ResourcePairTotal pair;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final numbers = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 2;
    final percentages = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 1;
    final percent = '${percentages.format(pair.percentage)}%';
    final bold = TextStyle(
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );
    Widget line(List<Widget> children) => Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: children,
    );
    return Container(
      key: ValueKey(('resource-pair', pair.planName, pair.factName)),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(color: colors.onSurfaceVariant),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line([
              Text(pair.planName),
              Text(numbers.format(pair.plan), style: bold),
            ]),
            const SizedBox(height: 10),
            Semantics(
              label: '${pair.factName}: $percent',
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: pair.progress,
                  minHeight: 8,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 10),
            line([
              Text(pair.factName),
              Text(percent, style: bold.copyWith(color: colors.primary)),
              Text(numbers.format(pair.fact), style: bold),
            ]),
          ],
        ),
      ),
    );
  }
}

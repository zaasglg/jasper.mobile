import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_theme.dart';
import 'app_translations.dart';
import 'locale_cubit.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, required this.cubit});
  final LocaleCubit cubit;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LocaleCubit, AppLocaleState>(
        bloc: cubit,
        builder: (context, state) {
          final colors = AppColors.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Язык интерфейса'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: state.code,
                backgroundColor: colors.quietSurface,
                thumbColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF484950)
                    : Colors.white,
                padding: const EdgeInsets.all(4),
                onValueChanged: (value) {
                  if (!state.saving && value != null && value != state.code) {
                    cubit.select(value);
                  }
                },
                children: {
                  for (final entry in const {
                    'ru': 'Русский',
                    'kk': 'Қазақша',
                  }.entries)
                    entry.key: Padding(
                      key: ValueKey('language-${entry.key}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.ink,
                          fontWeight: state.code == entry.key
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                },
              ),
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  tr(context, state.error!),
                  style: TextStyle(color: colors.error, fontSize: 12),
                ),
              ],
            ],
          );
        },
      );
}

import 'package:flutter/cupertino.dart';
import '../../../core/widgets/app_settings_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import 'notification_preferences_cubit.dart';

class NotificationPreferencesSection extends StatelessWidget {
  const NotificationPreferencesSection({super.key, required this.cubit});
  final NotificationPreferencesCubit cubit;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<NotificationPreferencesCubit, NotificationPreferencesState>(
    bloc: cubit,
    builder: (context, state) {
      final value = state.value;
      Widget toggle(String title, bool checked, void Function(bool) change) =>
          InkWell(
            onTap: state.saving || state.owner == null
                ? null
                : () => change(!checked),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(context, title),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CupertinoSwitch(
                    value: checked,
                    onChanged: state.saving || state.owner == null
                        ? null
                        : change,
                  ),
                ],
              ),
            ),
          );
      Widget footnote(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          tr(context, text),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.of(context).muted,
          ),
        ),
      );
      String clock(int minute) =>
          '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
      Future<void> pick(bool start) async {
        final minute = start ? value.quietStart : value.quietEnd;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
        );
        if (time == null || !context.mounted || cubit.isClosed) return;
        final total = time.hour * 60 + time.minute;
        await cubit.update(
          start
              ? cubit.state.value.copyWith(quietStart: total)
              : cubit.state.value.copyWith(quietEnd: total),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, 'На этом устройстве'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.of(context).muted,
              ),
            ),
            const SizedBox(height: 8),
            AppSettingsGroup(
              children: [
                toggle(
                  'Сообщения',
                  value.messages,
                  (v) => cubit.update(value.copyWith(messages: v)),
                ),
                toggle(
                  'Упоминания',
                  value.mentions,
                  (v) => cubit.update(value.copyWith(mentions: v)),
                ),
                toggle(
                  'Напоминания о сроках',
                  value.deadlines,
                  (v) => cubit.update(value.copyWith(deadlines: v)),
                ),
              ],
            ),
            footnote('Сроки — напоминания, заданные в ежедневнике.'),
            AppSettingsGroup(
              children: [
                toggle(
                  'Тихие часы',
                  value.quietEnabled,
                  (v) => cubit.update(value.copyWith(quietEnabled: v)),
                ),
                if (value.quietEnabled) ...[
                  ListTile(
                    title: Text(
                      tr(context, 'Начало'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Text(clock(value.quietStart)),
                    onTap: state.saving ? null : () => pick(true),
                  ),
                  ListTile(
                    title: Text(
                      tr(context, 'Окончание'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Text(clock(value.quietEnd)),
                    onTap: state.saving ? null : () => pick(false),
                  ),
                ],
              ],
            ),
            if (value.quietEnabled)
              footnote(
                value.quietStart == value.quietEnd
                    ? 'Уведомления отключены на весь день.'
                    : 'Ежедневно по местному времени устройства.',
              ),
            footnote(
              'Звонки продолжат поступать. Уведомления останутся в приложении.',
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                tr(context, state.error!),
                style: TextStyle(color: AppColors.of(context).error),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: state.saving
                      ? null
                      : state.owner == null
                      ? cubit.load
                      : cubit.synchronize,
                  child: Text(tr(context, 'Повторить')),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

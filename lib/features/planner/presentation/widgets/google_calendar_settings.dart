import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/repositories/planner_repository.dart';
import '../cubit/google_calendar_cubit.dart';

class GoogleCalendarSettings extends StatefulWidget {
  const GoogleCalendarSettings({required this.cubit, super.key});
  final GoogleCalendarCubit cubit;
  @override
  State<GoogleCalendarSettings> createState() => _GoogleCalendarSettingsState();
}

class _GoogleCalendarSettingsState extends State<GoogleCalendarSettings> {
  bool _opening = false;
  String? _error;
  Future<void> _connect() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final url = await widget.cubit.repository.authorizationUrl();
      if (!mounted) return;
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const PlannerException('Не удалось открыть браузер.');
      }
      if (!mounted) return;
      widget.cubit.awaitAuthorization();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PlannerException
              ? e.message
              : 'Не удалось открыть подключение Google.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<GoogleCalendarCubit, GoogleCalendarState>(
    bloc: widget.cubit,
    builder: (context, state) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Google Календарь'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Закрыть'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.connection.connected
                  ? tr(context, 'Подключено')
                  : tr(context, 'Не подключено'),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'События Google отображаются в ежедневнике. Задачи Jospar с датой и временем отправляются в основной календарь Google примерно раз в минуту.',
              ),
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            if (state.connection.connected && !state.connection.canWrite)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  tr(
                    context,
                    'Разрешено только чтение. Подключите заново и разрешите управление событиями, чтобы задачи появились в Google.',
                  ),
                ),
              ),
            if (state.connection.connected) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(context, 'Показывать события Google'),
                  style: TextStyle(fontSize: 14),
                ),
                value: state.showEvents,
                onChanged: widget.cubit.showEvents,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(context, 'Праздничные календари Google'),
                  style: TextStyle(fontSize: 14),
                ),
                value: state.includeHolidays,
                onChanged: state.loading ? null : widget.cubit.holidays,
              ),
            ],
            if (_error != null || state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error ?? state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              tr(
                context,
                'После разрешения доступа в браузере вернитесь в Jospar. Подключение проверится автоматически.',
              ),
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _opening || state.loading ? null : _connect,
              child: Text(
                _opening
                    ? tr(context, 'Открываем Google…')
                    : state.connection.connected
                    ? tr(context, 'Подключить заново')
                    : tr(context, 'Подключить Google Календарь'),
              ),
            ),
            TextButton(
              onPressed: state.loading ? null : () => widget.cubit.refresh(),
              child: Text(
                state.loading
                    ? tr(context, 'Проверка подключения…')
                    : tr(context, 'Проверить подключение'),
              ),
            ),
            if (state.connection.connected)
              TextButton(
                onPressed: state.loading
                    ? null
                    : () async {
                        final confirmed = await showAppConfirmation(
                          context,
                          tr(context, 'Отключить Google?'),
                          tr(
                            context,
                            'Подключение общее с Google Drive. Отключение также уберёт доступ к Drive. События Google сохранятся.',
                          ),
                          confirmLabel: 'Отключить',
                          destructive: true,
                        );
                        if (confirmed && mounted) {
                          await widget.cubit.disconnect();
                        }
                      },
                child: Text(tr(context, 'Отключить Google')),
              ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'Название и время задач меняйте в Jospar. При удалении задачи из ежедневника связанное событие удалится из Google. Остальные события Google не изменяются.',
              ),
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

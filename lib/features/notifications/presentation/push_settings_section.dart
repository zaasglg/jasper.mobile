import '../../../core/widgets/app_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_icon_sizes.dart';
import 'push_cubit.dart';

class PushSettingsSection extends StatefulWidget {
  const PushSettingsSection({required this.cubit, super.key});
  final PushCubit cubit;
  @override
  State<PushSettingsSection> createState() => _PushSettingsSectionState();
}

class _PushSettingsSectionState extends State<PushSettingsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.cubit.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.cubit.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<PushCubit, PushState>(
    bloc: widget.cubit,
    builder: (context, state) {
      if (!state.supported) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Уведомления',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF777C89),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      LucideIcons.bell,
                      size: AppIconSizes.standard,
                    ),
                    title: const Text(
                      'Push-уведомления',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      state.loading
                          ? 'Проверка…'
                          : state.registrationError ??
                                state.error ??
                                (!state.authorized
                                    ? 'Не разрешены на устройстве'
                                    : !state.channelEnabled
                                    ? 'Канал уведомлений отключён'
                                    : state.registered
                                    ? 'Подключены'
                                    : state.token == null
                                    ? 'Ожидание регистрации устройства'
                                    : 'Разрешены. Подключение к серверу…'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      LucideIcons.chevronRight,
                      size: AppIconSizes.standard,
                    ),
                    onTap: state.loading ? null : widget.cubit.openSettings,
                  ),
                  if (!state.authorized)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: FilledButton(
                        onPressed: state.loading
                            ? null
                            : widget.cubit.requestPermission,
                        child: const Text('Разрешить уведомления'),
                      ),
                    ),
                  if (state.error != null ||
                      state.registrationError != null ||
                      (state.authorized && state.token == null))
                    TextButton(
                      onPressed: state.loading ? null : widget.cubit.refresh,
                      child: const Text('Повторить проверку'),
                    ),
                  if (kDebugMode && state.token != null)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: state.token!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            appSnackBar(
                              context: context,
                              tone: AppSnackBarTone.success,
                              content: Text(
                                'Токен устройства скопирован для теста Firebase.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Скопировать токен для теста Firebase',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

import '../../../../core/di/service_locator.dart';
import '../../../notifications/presentation/push_cubit.dart';
import '../../../notifications/presentation/push_settings_section.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../assistant/presentation/screens/assistant_screen.dart';

class VoiceSettingsController {
  const VoiceSettingsController({
    required this.isListening,
    required this.onToggleListening,
  });

  final ValueListenable<bool> isListening;
  final Future<void> Function() onToggleListening;
}

typedef SettingsNavigationData = ({
  VoiceSettingsController? voice,
  WorkspaceCubit workspace,
});

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.voiceController, this.workspaceCubit});

  final VoiceSettingsController? voiceController;
  final WorkspaceCubit? workspaceCubit;

  static const _accent = Color(0xFF6D5FE0);
  static const _ink = Color(0xFF242631);
  static const _muted = Color(0xFF777C89);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        title: Text(
          'Настройки',
          style: GoogleFonts.manrope(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        children: [
          Text(
            'Голосовой помощник',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (voiceController != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: voiceController!.isListening,
                    builder: (context, isListening, _) => _SettingsRow(
                      key: const Key('settings-voice-wake'),
                      icon: isListening
                          ? LucideIcons.audioLines
                          : LucideIcons.mic,
                      title: 'Слушать «Ok, Jospar»',
                      subtitle: isListening
                          ? 'Микрофон активен — произнесите команду'
                          : 'Голосовой вызов на 45 секунд',
                      trailing: Switch.adaptive(
                        value: isListening,
                        activeTrackColor: _accent,
                        onChanged: (_) => voiceController!.onToggleListening(),
                      ),
                      onTap: voiceController!.onToggleListening,
                    ),
                  )
                else
                  const _SettingsRow(
                    icon: LucideIcons.micOff,
                    title: 'Слушать «Ok, Jospar»',
                    subtitle: 'Голосовой вызов недоступен на этом устройстве',
                  ),
                const Padding(
                  padding: EdgeInsets.only(left: 72),
                  child: Divider(height: 1, color: Color(0xFFEEEFF3)),
                ),
                _SettingsRow(
                  key: const Key('settings-siri-help'),
                  icon: LucideIcons.sparkles,
                  title: 'Вызов через Siri',
                  subtitle: 'Настроить запуск с любого экрана',
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    size: AppIconSizes.standard,
                    color: _muted,
                  ),
                  onTap: () => showVoiceLaunchHelp(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Прослушивание работает только пока Jospar открыт. Доступ к микрофону можно отключить в системных настройках.',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                height: 1.45,
                color: _muted,
              ),
            ),
          ),
          if (workspaceCubit != null) ...[
            const SizedBox(height: 28),
            Text(
              'Рабочее пространство',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
                bloc: workspaceCubit,
                builder: (context, state) {
                  final selected = state is WorkspaceLoaded
                      ? state.selected
                      : null;
                  return _SettingsRow(
                    key: const Key('settings-workspace'),
                    icon: LucideIcons.settings2,
                    title: 'Настройки workspace',
                    subtitle: selected?.name ?? 'Выберите workspace',
                    trailing: const Icon(
                      LucideIcons.chevronRight,
                      size: AppIconSizes.standard,
                      color: _muted,
                    ),
                    onTap: selected == null
                        ? null
                        : () async {
                            final cubit = workspaceCubit!;
                            await context.push(
                              '/manage/workspaces/${Uri.encodeComponent(selected.id)}',
                            );
                            if (!cubit.isClosed) await cubit.load(force: true);
                          },
                  );
                },
              ),
            ),
          ],
          if (sl.isRegistered<PushCubit>() && sl<PushCubit>().state.supported)
            PushSettingsSection(cubit: sl<PushCubit>()),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SettingsScreen._accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                size: AppIconSizes.standard,
                color: SettingsScreen._accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SettingsScreen._ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      height: 1.3,
                      color: SettingsScreen._muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

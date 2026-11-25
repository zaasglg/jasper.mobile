import 'package:flutter/cupertino.dart';
import '../../../../core/widgets/app_settings_group.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
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

typedef ProfileNavigationData = ({
  VoiceSettingsController? voice,
  WorkspaceCubit workspace,
});

class ProfileSettingsSections extends StatelessWidget {
  const ProfileSettingsSections({
    super.key,
    this.voiceController,
    this.workspaceCubit,
  });
  final VoiceSettingsController? voiceController;
  final WorkspaceCubit? workspaceCubit;
  static const _accent = Color(0xFF6D5FE0);
  static Color _ink(BuildContext context) => AppColors.of(context).ink;
  static Color _muted(BuildContext context) => AppColors.of(context).muted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        tr(context, 'Голосовой помощник'),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: _muted(context),
        ),
      ),
      const SizedBox(height: 10),
      AppSettingsGroup(
        dividerInset: 58,
        children: [
          if (voiceController != null)
            ValueListenableBuilder<bool>(
              valueListenable: voiceController!.isListening,
              builder: (context, isListening, _) => _SettingsRow(
                key: const Key('settings-voice-wake'),
                icon: isListening ? LucideIcons.audioLines : LucideIcons.mic,
                title: 'Слушать «Ok, Jospar»',
                subtitle: isListening
                    ? 'Микрофон активен — произнесите команду'
                    : 'Голосовой вызов на 45 секунд',
                trailing: CupertinoSwitch(
                  value: isListening,
                  activeTrackColor: CupertinoColors.systemGreen,
                  onChanged: (_) => voiceController!.onToggleListening(),
                ),
                onTap: voiceController!.onToggleListening,
              ),
            )
          else
            _SettingsRow(
              icon: LucideIcons.micOff,
              title: tr(context, 'Слушать «Ok, Jospar»'),
              subtitle: tr(
                context,
                'Голосовой вызов недоступен на этом устройстве',
              ),
            ),
          _SettingsRow(
            key: const Key('settings-siri-help'),
            icon: LucideIcons.sparkles,
            title: 'Вызов через Siri',
            subtitle: 'Настроить запуск с любого экрана',
            trailing: Icon(
              LucideIcons.chevronRight,
              size: AppIconSizes.standard,
              color: _muted(context),
            ),
            onTap: () => showVoiceLaunchHelp(context),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          tr(
            context,
            'Прослушивание работает только пока Jospar открыт. Доступ к микрофону можно отключить в системных настройках.',
          ),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            height: 1.45,
            color: _muted(context),
          ),
        ),
      ),
      if (workspaceCubit != null) ...[
        const SizedBox(height: 28),
        Text(
          tr(context, 'Рабочее пространство'),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _muted(context),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: AppSettingsGroup.surfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
            bloc: workspaceCubit,
            builder: (context, state) {
              final selected = state is WorkspaceLoaded ? state.selected : null;
              return _SettingsRow(
                key: const Key('settings-workspace'),
                icon: LucideIcons.settings2,
                title: 'Настройки workspace',
                subtitle: selected?.name ?? 'Выберите workspace',
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: AppIconSizes.standard,
                  color: _muted(context),
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
  );
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
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: ProfileSettingsSections._accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, title),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: ProfileSettingsSections._ink(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr(context, subtitle),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.3,
                      color: ProfileSettingsSections._muted(context),
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

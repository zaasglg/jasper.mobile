import '../../../../core/widgets/app_settings_group.dart';
import '../../../profile/presentation/widgets/profile_settings_sections.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/localization/language_selector.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/theme/theme_selector.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_theme.dart';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.settings});
  final ProfileNavigationData? settings;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ProfileCubit>(create: (_) => sl<ProfileCubit>()..load()),
        BlocProvider<AuthCubit>(create: (_) => sl<AuthCubit>()),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) context.go('/login');
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                appSnackBar(
                  context: context,
                  tone: AppSnackBarTone.error,
                  content: Text(tr(context, state.message)),
                ),
              );
          }
        },
        child: const _ProfileView(),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSettingsGroup.pageColor(context),
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.of(context).border
                : const Color(0xFFE5E7EB),
          ),
        ),
        backgroundColor: AppSettingsGroup.pageColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: AppBackButton(
          onPressed: () => context.pop(),
          color: AppColors.of(context).ink,
        ),
        title: Text(
          tr(context, 'Профиль'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.of(context).ink,
          ),
        ),
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded && state.photoError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context: context,
                tone: AppSnackBarTone.error,
                content: Text(state.photoError!),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileFailure) {
            return _ProfileError(message: state.message);
          }
          if (state is ProfileLoaded) {
            return _ProfileContent(profile: state);
          }
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2.5,
            ),
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  const _ProfileContent({required this.profile});

  final ProfileLoaded profile;

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  Color get _mutedText => Theme.of(context).brightness == Brightness.dark
      ? AppColors.of(context).muted
      : const Color(0xFF64748B);
  Color get _subtleText => Theme.of(context).brightness == Brightness.dark
      ? AppColors.of(context).muted
      : const Color(0xFF94A3B8);
  static const _dangerFg = Color(0xFFD92D45);
  static const _appVersionLabel = 'Версия 1.4.2 (Сборка 240)';

  bool _isPicking = false;

  Future<void> _pickPhoto() async {
    setState(() => _isPicking = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty || !mounted) return;
      if ((await files.first.length() ?? 0) > 20 * 1024 * 1024) {
        throw const FormatException('Выберите фото размером до 20 МБ.');
      }
      final bytes = await files.first.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 256,
        targetHeight: 256,
        allowUpscaling: false,
      );
      late final String dataUrl;
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) throw const FormatException();
          dataUrl =
              'data:image/png;base64,${base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))}';
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      if (mounted) await context.read<ProfileCubit>().updateAvatar(dataUrl);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(
              error is FormatException && error.message.isNotEmpty
                  ? error.message
                  : tr(
                      context,
                      'Не удалось открыть фото. Выберите другое изображение.',
                    ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _copyEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.success,
          content: Text(tr(context, 'Почта скопирована')),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.profile.profile;
    final busy = _isPicking || widget.profile.isSavingPhoto;
    final displayName = user.name.isNotEmpty ? user.name : 'Пользователь';
    final isKazakh = Localizations.localeOf(context).languageCode == 'kk';

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: context.read<ProfileCubit>().load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            sliver: SliverList.list(
              children: [
                _buildHeroCard(
                  displayName: displayName,
                  email: user.email,
                  avatarUrl: user.avatarUrl,
                  busy: busy,
                ),
                const SizedBox(height: 16),
                _buildSectionTitle(tr(context, 'Учётная запись')),

                AppSettingsGroup(
                  dividerInset: 58,
                  children: [
                    _buildProfileItem(
                      icon: LucideIcons.user,

                      label: 'Имя',
                      value: user.name.isNotEmpty ? user.name : 'Не указано',
                    ),
                    _buildProfileItem(
                      icon: LucideIcons.mail,

                      label: 'Электронная почта',
                      value: user.email.isNotEmpty ? user.email : 'Не указана',
                      trailing: user.email.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('profile_copy_email_button'),
                              tooltip: tr(context, 'Скопировать почту'),
                              onPressed: () => _copyEmail(user.email),
                              style: IconButton.styleFrom(
                                foregroundColor: _mutedText,
                                minimumSize: const Size.square(44),
                              ),
                              icon: const Icon(LucideIcons.copy, size: 17),
                            ),
                    ),
                    _buildProfileItem(
                      icon: LucideIcons.shieldCheck,

                      label: 'Роль в системе',
                      value: tr(context, user.roleLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sl.isRegistered<ThemeCubit>()) ...[
                  _buildSectionTitle(tr(context, 'Внешний вид')),
                  _buildThemeSetting(isKazakh),
                  const SizedBox(height: 16),
                ],
                if (sl.isRegistered<LocaleCubit>()) ...[
                  const SizedBox(height: 16),
                  LanguageSelector(cubit: sl<LocaleCubit>()),
                  const SizedBox(height: 16),
                ],
                ProfileSettingsSections(
                  voiceController: context
                      .findAncestorWidgetOfExactType<ProfileScreen>()
                      ?.settings
                      ?.voice,
                  workspaceCubit: context
                      .findAncestorWidgetOfExactType<ProfileScreen>()
                      ?.settings
                      ?.workspace,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle(tr(context, 'Безопасность')),

                Material(
                  color: AppSettingsGroup.surfaceColor(context),
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('profile_qr_login_button'),
                    onTap: () => context.push(
                      '/qr-sessions',
                      extra: (name: displayName, email: user.email),
                    ),
                    child: _buildSecurityItem(
                      icon: LucideIcons.monitor,

                      title: isKazakh ? 'QR сеанстары' : 'Активные сеансы',
                      subtitle: isKazakh
                          ? 'Қосылған құрылғыларды басқару'
                          : 'Подключённые устройства',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLogoutButton(),
                const SizedBox(height: 14),
                _buildVersionFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSetting(bool isKazakh) {
    final cubit = sl<ThemeCubit>();
    return BlocBuilder<ThemeCubit, ThemeMode>(
      bloc: cubit,
      builder: (context, mode) {
        final colors = AppColors.of(context);
        return Material(
          color: AppSettingsGroup.surfaceColor(context),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('profile_theme_button'),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              backgroundColor: colors.canvas,
              constraints: const BoxConstraints(maxWidth: 480),
              isScrollControlled: true,
              builder: (sheetContext) => SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ThemeSelector(
                    cubit: cubit,
                    onSelected: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ),
            ),
            child: _buildProfileItem(
              icon: switch (mode) {
                ThemeMode.system => LucideIcons.monitor,
                ThemeMode.light => LucideIcons.sun,
                ThemeMode.dark => LucideIcons.moon,
              },

              label: isKazakh ? 'Қолданба тақырыбы' : 'Тема приложения',
              value: switch (mode) {
                ThemeMode.system => isKazakh ? 'Жүйелік' : 'Как на устройстве',
                ThemeMode.light => isKazakh ? 'Ашық' : 'Светлая',
                ThemeMode.dark => isKazakh ? 'Қараңғы' : 'Тёмная',
              },
              trailing: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: colors.muted,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard({
    required String displayName,
    required String email,
    required String? avatarUrl,
    required bool busy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.of(context).border
                          : const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                  ),
                  child: ProfileAvatar(size: 68, avatarUrl: avatarUrl),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: avatarUrl == null
                        ? tr(context, 'Добавить фото')
                        : tr(context, 'Изменить фото'),
                    child: Material(
                      color: const Color(0xFF5B4FE9),
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('profile_change_photo_button'),
                        onTap: busy ? null : _pickPhoto,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: busy
                                ? const SizedBox.square(
                                    dimension: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.camera,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.of(context).ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, color: _mutedText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _mutedText,
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _mutedText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: _mutedText),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).ink,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _mutedText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: _mutedText),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: _subtleText),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('profile_logout_button'),
            onPressed: isLoading
                ? null
                : () => context.read<AuthCubit>().logout(),
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _dangerFg,
                    ),
                  )
                : const Icon(LucideIcons.logOut, size: 18),
            label: Text(
              isLoading
                  ? tr(context, 'Выходим…')
                  : tr(context, 'Выйти из аккаунта'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _dangerFg,
              disabledForegroundColor: _dangerFg.withValues(alpha: 0.6),
              backgroundColor: AppSettingsGroup.surfaceColor(context),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionFooter() {
    return Text(
      _appVersionLabel,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(fontSize: 12, color: _subtleText),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.circleAlert,
              size: AppIconSizes.standard,
              color: Color(0xFF9AA0A6),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF6F7682),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: context.read<ProfileCubit>().load,
              child: Text(tr(context, 'Повторить')),
            ),
          ],
        ),
      ),
    );
  }
}

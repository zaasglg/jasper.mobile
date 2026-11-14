import '../../../../core/theme/app_icon_sizes.dart';
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
  const ProfileScreen({super.key});

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
              ..showSnackBar(SnackBar(content: Text(state.message)));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(child: Text('Jospar')),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: Color(0xFF1A1A1A),
            size: AppIconSizes.standard,
          ),
        ),
        title: Text(
          'Профиль',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded && state.photoError != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.photoError!)));
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
              color: Color(0xFF6D5FE0),
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
          SnackBar(
            content: Text(
              error is FormatException && error.message.isNotEmpty
                  ? error.message
                  : 'Не удалось открыть фото. Выберите другое изображение.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.profile.profile;
    final busy = _isPicking || widget.profile.isSavingPhoto;
    final displayName = user.name.isNotEmpty ? user.name : 'Пользователь';

    return RefreshIndicator(
      color: const Color(0xFF6D5FE0),
      onRefresh: context.read<ProfileCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          Row(
            children: [
              ProfileAvatar(size: 52, avatarUrl: user.avatarUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.email.isNotEmpty)
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('profile_change_photo_button'),
                onPressed: busy ? null : _pickPhoto,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  busy
                      ? 'Сохраняем…'
                      : user.avatarUrl == null
                      ? 'Добавить фото'
                      : 'Изменить фото',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 32),
          Text(
            'УЧЁТНАЯ ЗАПИСЬ',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF858297),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ProfileDataRow(
                  icon: LucideIcons.userRound,
                  label: 'Имя',
                  value: user.name.isNotEmpty ? user.name : 'Не указано',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1, color: Color(0xFFF0EEF5)),
                ),
                _ProfileDataRow(
                  icon: LucideIcons.mail,
                  label: 'Электронная почта',
                  value: user.email.isNotEmpty ? user.email : 'Не указана',
                  onCopy: user.email.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: user.email),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Почта скопирована'),
                              ),
                            );
                        },
                ),
                const Divider(height: 1),
                _ProfileDataRow(
                  icon: LucideIcons.shield,
                  label: 'Роль',
                  value: user.roleLabel,
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('БЕЗОПАСНОСТЬ', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: ListTile(
              key: const Key('profile_qr_login_button'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 6,
              ),
              leading: const Icon(
                LucideIcons.monitor,
                color: Color(0xFF55565C),
              ),
              title: Text(
                Localizations.localeOf(context).languageCode == 'kk'
                    ? 'QR сеанстары'
                    : 'Активные сеансы',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                Localizations.localeOf(context).languageCode == 'kk'
                    ? 'Қосылған құрылғыларды басқару'
                    : 'Подключённые устройства',
              ),
              trailing: const Icon(
                LucideIcons.chevronRight,
                size: AppIconSizes.standard,
              ),
              onTap: () => context.push(
                '/qr-sessions',
                extra: (name: displayName, email: user.email),
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 28),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoading;
              return SizedBox(
                height: 54,
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
                            color: Color(0xFFD64545),
                          ),
                        )
                      : const Icon(
                          LucideIcons.logOut,
                          size: AppIconSizes.standard,
                        ),
                  label: Text(isLoading ? 'Выходим…' : 'Выйти из аккаунта'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC44E58),
                    disabledForegroundColor: const Color(0xFFC44E58),
                    backgroundColor: Colors.transparent,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileDataRow extends StatelessWidget {
  const _ProfileDataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF292735),
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Скопировать почту',
              onPressed: onCopy,
              icon: const Icon(
                LucideIcons.copy,
                size: AppIconSizes.standard,
                color: Color(0xFF858297),
              ),
            ),
        ],
      ),
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
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: const Color(0xFF6F7682),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: context.read<ProfileCubit>().load,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

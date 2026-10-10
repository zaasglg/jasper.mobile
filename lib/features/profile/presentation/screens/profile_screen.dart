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
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1A1A1A)),
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
      body: BlocBuilder<ProfileCubit, ProfileState>(
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

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final ProfileLoaded profile;

  @override
  Widget build(BuildContext context) {
    final user = profile.profile;
    final displayName = user.name.isNotEmpty ? user.name : 'Пользователь';

    return RefreshIndicator(
      color: const Color(0xFF6D5FE0),
      onRefresh: context.read<ProfileCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFECE9FC),
              ),
              child: ProfileAvatar(size: 88, avatarUrl: user.avatarUrl),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF292735),
            ),
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: const Color(0xFF858297),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Данные аккаунта',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF858297),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              ],
            ),
          ),
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
                      : const Icon(LucideIcons.logOut, size: 19),
                  label: Text(isLoading ? 'Выходим…' : 'Выйти из аккаунта'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC44E58),
                    disabledForegroundColor: const Color(0xFFC44E58),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFEEDDE0)),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EEFD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF6D5FE0)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: const Color(0xFF858297),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF292735),
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Скопировать почту',
              onPressed: onCopy,
              icon: const Icon(
                LucideIcons.copy,
                size: 18,
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
              size: 32,
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

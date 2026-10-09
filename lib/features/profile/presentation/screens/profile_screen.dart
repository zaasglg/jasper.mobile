import 'package:flutter/material.dart';
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 102,
            height: 102,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6D5FE0).withValues(alpha: 0.2),
                width: 3,
              ),
            ),
            child: ProfileAvatar(size: 90, avatarUrl: user.avatarUrl),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.email,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9AA0A6),
              ),
            ),
          ],
          const SizedBox(height: 32),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoading;
              return SizedBox(
                width: 220,
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
                            color: Color(0xFFD64545),
                          ),
                        )
                      : const Icon(LucideIcons.logOut, size: 19),
                  label: Text(isLoading ? 'Выходим…' : 'Выйти'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD64545),
                    disabledForegroundColor: const Color(0xFFD64545),
                    side: const BorderSide(color: Color(0xFFF0CACA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

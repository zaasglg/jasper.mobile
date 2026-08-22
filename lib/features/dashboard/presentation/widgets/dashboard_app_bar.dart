import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../shell/presentation/screens/main_shell.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF5F6F8),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: MainShell.openDrawer,
        tooltip: 'Меню',
        icon: const Icon(LucideIcons.menu, color: Color(0xFF1A1A1A)),
      ),
      title: Text(
        'Дашборд',
        style: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          tooltip: 'Поиск',
          icon: const Icon(LucideIcons.search, color: Color(0xFF1A1A1A)),
        ),
        IconButton(
          onPressed: () {},
          tooltip: 'AI',
          icon: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9DCE3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'AI',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF4A4F58),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(LucideIcons.bell, color: Color(0xFF1A1A1A)),
          tooltip: 'Уведомления',
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: () => context.push('/profile'),
            tooltip: 'Профиль',
            icon: BlocBuilder<ProfileCubit, ProfileState>(
              buildWhen: (previous, current) => current is ProfileLoaded,
              builder: (context, state) {
                final avatarUrl = state is ProfileLoaded
                    ? state.profile.avatarUrl
                    : null;
                return ProfileAvatar(
                  size: 32,
                  iconSize: 18,
                  avatarUrl: avatarUrl,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

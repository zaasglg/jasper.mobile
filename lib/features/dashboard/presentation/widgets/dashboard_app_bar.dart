import '../../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../shell/presentation/screens/main_shell.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({super.key});

  static const double _iconSize = AppIconSizes.standard;
  static const Color _iconColor = Color(0xFF1A1A1A);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: MainShell.openDrawer,
        tooltip: 'Меню',
        icon: const Icon(LucideIcons.menu, size: _iconSize, color: _iconColor),
      ),
      title: BlocSelector<WorkspaceCubit, WorkspaceState, String>(
        selector: (state) {
          final name = state is WorkspaceLoaded
              ? state.selected?.name.trim()
              : null;
          return name == null || name.isEmpty ? 'Воркспейс' : name;
        },
        builder: (context, name) => Tooltip(
          message: name,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/dashboard/search'),
          tooltip: 'Поиск',
          icon: const Icon(
            LucideIcons.search,
            size: _iconSize,
            color: _iconColor,
          ),
        ),
        IconButton(
          onPressed: () => MainShell.openAssistant(context),
          tooltip: 'ИИ-помощник',
          icon: SvgPicture.asset(
            'assets/images/JBee.svg',
            key: const Key('dashboard-ai-icon'),
            width: 24,
            height: 24,
          ),
        ),
        IconButton(
          onPressed: () => context.push('/activity/notifications'),
          icon: const Icon(
            LucideIcons.bell,
            size: _iconSize,
            color: _iconColor,
          ),
          tooltip: 'Уведомления',
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: () async {
              await context.push('/profile');
              if (context.mounted) await context.read<ProfileCubit>().load();
            },
            tooltip: 'Профиль',
            icon: BlocBuilder<ProfileCubit, ProfileState>(
              buildWhen: (previous, current) => current is ProfileLoaded,
              builder: (context, state) {
                final avatarUrl = state is ProfileLoaded
                    ? state.profile.avatarUrl
                    : null;
                return ProfileAvatar(
                  size: 32,
                  iconSize: _iconSize,
                  iconColor: _iconColor,
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

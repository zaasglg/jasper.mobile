import '../../../../core/theme/app_ui_tokens.dart';
import 'package:forui/forui.dart';
import '../../../../core/widgets/header_action.dart';
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
  const DashboardAppBar({
    this.pageActions = const [],
    this.pageTitle,
    this.accountTitle,
    this.bottom,
    super.key,
  });
  final PreferredSizeWidget? bottom;
  final String? pageTitle;
  final String? accountTitle;
  final List<Widget> pageActions;

  static const double _iconSize = AppSpacing.lg;
  static const Color _iconColor = Color(0xFF1A1A1A);

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight +
        (bottom?.preferredSize.height ?? 0) +
        (pageActions.isEmpty ? 0 : AppSpacing.touchTarget + AppSpacing.lg),
  );

  @override
  Widget build(BuildContext context) {
    return FTheme(
      data: Theme.of(context).brightness == Brightness.dark
          ? FTheme.neutral.dark.touch
          : FTheme.neutral.light.touch,
      child: AppBar(
        bottom:
            bottom ??
            (pageActions.isEmpty
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(
                      AppSpacing.touchTarget + AppSpacing.lg,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          if (pageTitle != null)
                            Expanded(
                              child: Text(
                                pageTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            )
                          else
                            const Spacer(),
                          ...pageActions,
                        ],
                      ),
                    ),
                  )),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: HeaderAction(
          onPressed: MainShell.openDrawer,
          tooltip: 'Меню',
          icon: const Icon(
            LucideIcons.menu,
            size: _iconSize,
            color: _iconColor,
          ),
        ),
        title: accountTitle != null
            ? Text(
                accountTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            : BlocSelector<WorkspaceCubit, WorkspaceState, String>(
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
        actions: [
          HeaderAction(
            onPressed: () => context.push('/dashboard/search'),
            tooltip: 'Поиск',
            icon: const Icon(
              LucideIcons.search,
              size: _iconSize,
              color: _iconColor,
            ),
          ),
          HeaderAction(
            onPressed: () => MainShell.openAssistant(context),
            tooltip: 'ИИ-помощник',
            icon: SvgPicture.asset(
              'assets/images/JBee.svg',
              key: const Key('dashboard-ai-icon'),
              width: 24,
              height: 24,
            ),
          ),
          HeaderAction(
            onPressed: () => context.push('/activity/notifications'),
            icon: const Icon(
              LucideIcons.bell,
              size: _iconSize,
              color: _iconColor,
            ),
            tooltip: 'Уведомления',
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: HeaderAction(
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
      ),
    );
  }
}

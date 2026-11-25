import '../../../workspaces/presentation/widgets/workspace_switcher.dart';
import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
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

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    this.pageActions = const [],
    this.compact = false,
    this.pageTitle,
    this.accountTitle,
    this.bottom,
    super.key,
  });
  final PreferredSizeWidget? bottom;
  final bool compact;
  final String? pageTitle;
  final String? accountTitle;
  final List<Widget> pageActions;

  static const double _iconSize = AppSpacing.lg;

  @override
  Size get preferredSize => Size.fromHeight(
    (compact ? 48.0 : kToolbarHeight) +
        (bottom?.preferredSize.height ?? 0) +
        (pageActions.isEmpty ? 0 : AppSpacing.touchTarget + AppSpacing.lg),
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FTheme(
      data: Theme.of(context).brightness == Brightness.dark
          ? FTheme.neutral.dark.touch
          : FTheme.neutral.light.touch,
      child: AppBar(
        toolbarHeight: compact ? 48 : kToolbarHeight,
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
        backgroundColor: AppColors.of(context).canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: accountTitle != null
            ? Text(
                accountTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            : const WorkspaceSwitcher(),
        actions: [
          HeaderAction(
            onPressed: () => context.push('/dashboard/search'),
            tooltip: tr(context, 'Поиск'),
            icon: Icon(LucideIcons.search, size: _iconSize, color: colors.ink),
          ),
          HeaderAction(
            onPressed: () => MainShell.openAssistant(context),
            tooltip: tr(context, 'ИИ-помощник'),
            icon: SvgPicture.asset(
              'assets/images/JBee.svg',
              key: const Key('dashboard-ai-icon'),
              colorFilter: Theme.of(context).brightness == Brightness.dark
                  ? ColorFilter.mode(colors.accent, BlendMode.srcIn)
                  : null,
              width: 24,
              height: 24,
            ),
          ),
          HeaderAction(
            onPressed: () => context.push('/activity/notifications'),
            icon: Icon(LucideIcons.bell, size: _iconSize, color: colors.ink),
            tooltip: tr(context, 'Уведомления'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: HeaderAction(
              onPressed: () async {
                await MainShell.openProfile(context);
                if (context.mounted) await context.read<ProfileCubit>().load();
              },
              tooltip: tr(context, 'Профиль'),
              icon: BlocBuilder<ProfileCubit, ProfileState>(
                buildWhen: (previous, current) => current is ProfileLoaded,
                builder: (context, state) {
                  final avatarUrl = state is ProfileLoaded
                      ? state.profile.avatarUrl
                      : null;
                  return ProfileAvatar(
                    size: 32,
                    iconSize: _iconSize,
                    iconColor: colors.ink,
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

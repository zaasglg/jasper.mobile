import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_ui_tokens.dart';
import '../../../core/theme/dashboard_surface.dart';
import '../../../core/widgets/user_avatar.dart';
import '../domain/entities/member_role.dart';
import '../domain/entities/space_member.dart';

class ParticipantBadge extends StatelessWidget {
  const ParticipantBadge(this.label, {this.accent = false, super.key});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: accent
            ? colors.outgoingMessage
            : (isDark ? colors.badgeSurface : const Color(0xFFF1F3F8)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          color: accent ? colors.accent : colors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ParticipantsProjectHeader extends StatelessWidget {
  const ParticipantsProjectHeader({
    required this.name,
    required this.count,
    super.key,
  });

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? colors.subtleSurface
                  : DashboardSurface.background,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? colors.border : DashboardSurface.border,
              ),
              boxShadow: isDark ? const [] : DashboardSurface.shadows,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.outgoingMessage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.folder,
                      size: 19,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr(context, 'ПРОЕКТ'),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.65,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.mdLg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Доступ к проекту'),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                ),
                Semantics(
                  label: tr(context, "Пользователей с доступом: {p0}", {
                    'p0': count,
                  }),
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.outgoingMessage,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectParticipantRow extends StatelessWidget {
  const ProjectParticipantRow({
    required this.member,
    this.onActions,
    super.key,
  });

  final SpaceMember member;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? colors.subtleSurface : DashboardSurface.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isDark ? colors.border : DashboardSurface.border,
          ),
          boxShadow: isDark ? const [] : DashboardSurface.shadows,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1,
                  child: UserAvatar(
                    size: 44,
                    userId: member.userId,
                    name: member.name,
                    avatarUrl: member.avatarUrl,
                    backgroundColor: colors.outgoingMessage,
                    foregroundColor: colors.accent,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.isEmpty ? member.email : member.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Semantics(
                          label: tr(context, "Роль в проекте: {p0}", {
                            'p0': memberRoleLabel(member.role),
                          }),
                          child: ParticipantBadge(memberRoleLabel(member.role)),
                        ),
                        if (member.access == 'project' ||
                            member.access == 'parent')
                          const ParticipantBadge('Гость проекта', accent: true),
                        if (member.isWorkspaceOwner)
                          const ParticipantBadge('Владелец воркспейса'),
                      ],
                    ),
                    if (member.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          member.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: colors.muted,
                          ),
                        ),
                      ),
                    if (member.about.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          member.about,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: colors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onActions != null) ...[
                const SizedBox(width: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.badgeSurface
                        : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    key: ValueKey('participant_actions_${member.userId}'),
                    tooltip: tr(context, 'Действия участника'),
                    onPressed: onActions,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      LucideIcons.ellipsis,
                      size: AppIconSizes.standard,
                      color: colors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ParticipantsSectionSurface extends StatelessWidget {
  const ParticipantsSectionSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? colors.subtleSurface : DashboardSurface.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? colors.border : DashboardSurface.border,
        ),
        boxShadow: isDark ? const [] : DashboardSurface.shadows,
      ),
      child: child,
    );
  }
}

class ParticipantsLinkActions extends StatelessWidget {
  const ParticipantsLinkActions({
    required this.copy,
    required this.share,
    super.key,
  });

  final Widget copy;
  final Widget share;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < AppSpacing.touchTarget * 7 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            copy,
            const SizedBox(height: AppSpacing.sm),
            share,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: copy),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: share),
        ],
      );
    },
  );
}

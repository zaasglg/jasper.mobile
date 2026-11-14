import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_ui_tokens.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/collaboration_models.dart';

class ParticipantBadge extends StatelessWidget {
  const ParticipantBadge(this.label, {this.accent = false, super.key});
  final String label;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent
            ? theme.colorScheme.primary.withValues(alpha: .08)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context)?.copyWith(
          color: accent
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.mdLg,
      AppSpacing.md,
      AppSpacing.mdLg,
      AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПРОЕКТ',
          style: AppTypography.caption(context)?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title(context),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Divider(),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Доступ к проекту',
                style: AppTypography.title(context),
              ),
            ),
            Semantics(
              label: 'Пользователей с доступом: $count',
              child: ExcludeSemantics(
                child: ParticipantBadge('$count', accent: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdLg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .4)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1,
                  child: UserAvatar(
                    size: AppSpacing.touchTarget,
                    userId: member.userId,
                    name: member.name,
                    avatarUrl: member.avatarUrl,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: .12,
                    ),
                    foregroundColor: theme.colorScheme.primary,
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
                      style: AppTypography.body(
                        context,
                      )?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Semantics(
                          label:
                              'Роль в проекте: ${memberRoleLabel(member.role)}',
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
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          member.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context)?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (member.about.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          member.about,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (onActions != null)
                IconButton(
                  key: ValueKey('participant_actions_${member.userId}'),
                  tooltip: 'Действия участника',
                  onPressed: onActions,
                  icon: const Icon(
                    LucideIcons.ellipsis,
                    size: AppIconSizes.standard,
                  ),
                ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : AppColors.accent.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .08),
        ),
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

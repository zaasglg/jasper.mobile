import 'package:jospar/core/localization/app_translations.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_action_menu.dart';
import '../../../core/widgets/app_back_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../../core/theme/app_ui_tokens.dart';
import 'project_participants_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/user_avatar.dart';
import '../domain/entities/space_member.dart';
import '../domain/entities/member_role.dart';
import '../data/project_participants_repository.dart';
import 'project_participants_cubit.dart';

class ProjectParticipantsScreen extends StatelessWidget {
  const ProjectParticipantsScreen({
    required this.id,
    this.repository,
    super.key,
  });
  final String id;
  final ProjectParticipantsRepository? repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ProjectParticipantsCubit(
      repository ?? ProjectParticipantsRepository(sl<Dio>()),
      id,
    )..load(),
    child: const _ParticipantsBody(),
  );
}

class _ParticipantsBody extends StatelessWidget {
  const _ParticipantsBody();
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ProjectParticipantsCubit, ProjectParticipantsState>(
        listenWhen: (a, b) => a.error != b.error && b.error != null,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context: context,
                tone: AppSnackBarTone.error,
                content: Text(tr(context, state.error!)),
              ),
            ),
        builder: (context, state) {
          final cubit = context.read<ProjectParticipantsCubit>();
          final compactAction =
              MediaQuery.sizeOf(context).width < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          void addParticipant() => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: const SafeArea(child: _AddParticipant()),
            ),
          );
          final canAdd = state.canManage && !state.loading && !state.saving;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                tr(context, 'Участники'),
                style: AppTypography.title(context),
              ),
              centerTitle: true,
              leading: AppBackButton(onPressed: () => context.pop()),
            ),
            floatingActionButton: !state.canManage
                ? null
                : compactAction
                ? FloatingActionButton(
                    key: const Key('participants_add'),
                    elevation: 0,
                    highlightElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    tooltip: tr(context, 'Добавить участника'),
                    onPressed: canAdd ? addParticipant : null,
                    child: const Icon(LucideIcons.userPlus),
                  )
                : FloatingActionButton.extended(
                    key: const Key('participants_add'),
                    elevation: 0,
                    highlightElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    onPressed: canAdd ? addParticipant : null,
                    icon: const Icon(
                      LucideIcons.plus,
                      size: AppIconSizes.standard,
                    ),
                    label: Text(tr(context, 'Добавить участника')),
                  ),
            body: SafeArea(
              child: state.space == null
                  ? Center(
                      child: state.loading
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: cubit.load,
                              child: Text(tr(context, 'Повторить')),
                            ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (!cubit.state.saving) await cubit.load();
                      },
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: ParticipantsProjectHeader(
                              name: state.space!.name,
                              count: state.members.length,
                            ),
                          ),
                          if (state.loading || state.saving)
                            const SliverToBoxAdapter(
                              child: LinearProgressIndicator(),
                            ),
                          if (state.error != null)
                            SliverToBoxAdapter(
                              child: TextButton(
                                onPressed: state.saving ? null : cubit.load,
                                child: Text(
                                  tr(context, 'Повторить загрузку участников'),
                                ),
                              ),
                            ),
                          if (state.members.isEmpty &&
                              !state.loading &&
                              state.error == null)
                            SliverPadding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  tr(context, 'В проекте пока нет участников.'),
                                ),
                              ),
                            ),
                          SliverList.builder(
                            itemCount: state.members.length,
                            itemBuilder: (context, index) {
                              final member = state.members[index];
                              return ProjectParticipantRow(
                                key: ValueKey(member.userId),
                                member: member,
                                onActions:
                                    state.canEdit(member) &&
                                        !state.loading &&
                                        !state.saving
                                    ? () => _actions(context, cubit, member)
                                    : null,
                              );
                            },
                          ),
                          if (state.invitations.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.all(AppSpacing.mdLg),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  tr(context, "Ожидают приглашения: {p0}", {
                                    'p0': state.invitations.length,
                                  }),
                                  style: AppTypography.title(context),
                                ),
                              ),
                            ),
                          SliverList.builder(
                            itemCount: state.invitations.length,
                            itemBuilder: (_, index) {
                              final invite = state.invitations[index];
                              return ListTile(
                                leading: const Icon(
                                  LucideIcons.mail,
                                  size: AppIconSizes.standard,
                                ),
                                title: Text(invite.email),
                                subtitle: Text(
                                  tr(context, "Приглашение отправлено · {p0}", {
                                    'p0': memberRoleLabel(invite.role),
                                  }),
                                ),
                              );
                            },
                          ),
                          if (state.canManage)
                            SliverPadding(
                              padding: const EdgeInsets.all(AppSpacing.mdLg),
                              sliver: SliverToBoxAdapter(
                                child: _ProjectLink(
                                  key: ValueKey(cubit.id),
                                  cubit: cubit,
                                  roles: state.invitationRoles,
                                  enabled: !state.loading && !state.saving,
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height:
                                  AppSpacing.touchTarget +
                                  AppSpacing.xl +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      );

  Future<void> _actions(
    BuildContext context,
    ProjectParticipantsCubit cubit,
    SpaceMember member,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(member.name),
                subtitle: Text(tr(context, 'Роль в этом проекте')),
              ),
              for (final role in cubit.state.rolesFor(member))
                ListTile(
                  title: Text(memberRoleLabel(role)),
                  trailing: role == member.role
                      ? const Icon(
                          LucideIcons.check,
                          size: AppIconSizes.standard,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, role),
                ),
              if (cubit.state.canRemove(member))
                ListTile(
                  leading: const Icon(
                    LucideIcons.userMinus,
                    size: AppIconSizes.standard,
                  ),
                  title: Text(tr(context, 'Удалить из проекта')),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted || !cubit.state.canEdit(member)) {
      return;
    }
    if (selected == 'remove') {
      if (!cubit.state.canRemove(member)) return;
      if (!await showAppConfirmation(
        context,
        tr(context, 'Удалить участника?'),
        tr(context, "{p0} потеряет доступ к проекту.", {
          'p0': member.name.isEmpty ? member.email : member.name,
        }),
        confirmLabel: 'Удалить',
        destructive: true,
      )) {
        return;
      }
      await cubit.mutate(
        () => cubit.repository.remove(cubit.id, member.userId),
      );
    } else if (selected != member.role &&
        cubit.state.rolesFor(member).contains(selected)) {
      await cubit.mutate(
        () => cubit.repository.changeRole(cubit.id, member.userId, selected),
      );
    }
  }
}

class _AddParticipant extends StatefulWidget {
  const _AddParticipant();
  @override
  State<_AddParticipant> createState() => _AddParticipantState();
}

class _AddParticipantState extends State<_AddParticipant> {
  final _query = TextEditingController();
  List<SpaceMember> _candidates = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _role = 'EXECUTOR';
  SpaceMember? _selected;
  bool _invalidEmail = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cubit = context.read<ProjectParticipantsCubit>();
    try {
      final workspaceId = cubit.state.space!.workspaceId ?? '';
      if (workspaceId.isEmpty) throw const FormatException();
      final candidates = await cubit.repository.collaboration.candidates(
        workspaceId,
      );
      if (mounted) setState(() => _candidates = candidates);
    } catch (e) {
      if (mounted) setState(() => _error = cubit.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _invited(SpaceMember user) => context
      .read<ProjectParticipantsCubit>()
      .state
      .invitations
      .any((invite) => invite.email.toLowerCase() == user.email.toLowerCase());
  bool _hasAccess(SpaceMember user) =>
      context.read<ProjectParticipantsCubit>().state.members.any(
        (m) =>
            m.userId == user.userId ||
            (m.email.isNotEmpty &&
                m.email.toLowerCase() == user.email.toLowerCase()),
      );
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProjectParticipantsCubit>();
    final query = _query.text.trim().toLowerCase();
    final matches = _candidates
        .where((m) => '${m.name} ${m.email}'.toLowerCase().contains(query))
        .toList();
    final duplicate =
        cubit.state.members.any((m) => m.email.toLowerCase() == query) ||
        cubit.state.invitations.any((m) => m.email.toLowerCase() == query);
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.mdLg,
                  AppSpacing.smMd,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Добавить участника'),
                        style: AppTypography.title(context),
                      ),
                    ),
                    IconButton(
                      key: const Key('participants_add_close'),
                      tooltip: tr(context, 'Закрыть'),
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        LucideIcons.x,
                        size: AppIconSizes.standard,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.mdLg),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const Key('participants_search'),
                              controller: _query,
                              enabled: !_sending,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              decoration: InputDecoration(
                                errorText: trn(
                                  context,
                                  _invalidEmail ? _error : null,
                                ),
                                errorMaxLines: 3,
                                labelText: tr(context, 'Имя или email'),
                                prefixIcon: const Icon(
                                  LucideIcons.search,
                                  size: AppIconSizes.standard,
                                ),
                              ),
                              onChanged: (_) => setState(() {
                                _selected = null;
                                _invalidEmail = false;
                                _error = null;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.smMd),
                            if (_loading) const LinearProgressIndicator(),
                            if (!_loading && matches.isEmpty)
                              Text(
                                tr(
                                  context,
                                  'Участники воркспейса не найдены. Можно пригласить по email.',
                                ),
                              ),
                            if (_error != null && !_invalidEmail) ...[
                              Text(
                                tr(context, _error!),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              TextButton(
                                onPressed: _sending ? null : _load,
                                child: Text(tr(context, 'Повторить поиск')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.mdLg,
                      ),
                      sliver: SliverList.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final user = matches[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(
                              size: AppSpacing.touchTarget,
                              userId: user.userId,
                              name: user.name,
                              avatarUrl: user.avatarUrl,
                            ),
                            title: Text(
                              user.name.isEmpty ? user.email : user.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _invited(user)
                                  ? tr(context, 'Приглашение уже отправлено')
                                  : _hasAccess(user)
                                  ? tr(context, 'Доступ уже предоставлен')
                                  : user.email,
                            ),
                            trailing: _selected?.userId == user.userId
                                ? const Icon(
                                    LucideIcons.circleCheck,
                                    size: AppIconSizes.standard,
                                  )
                                : null,
                            enabled:
                                !_sending &&
                                !_hasAccess(user) &&
                                !_invited(user) &&
                                user.email.isNotEmpty,
                            onTap: () => setState(() {
                              _selected = user;
                              _error = null;
                            }),
                          );
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.mdLg),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (duplicate)
                              Text(
                                tr(
                                  context,
                                  'Доступ уже предоставлен или приглашение отправлено.',
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              icon: const Icon(
                                LucideIcons.chevronDown,
                                size: AppIconSizes.standard,
                              ),
                              key: const Key('participants_add_role'),
                              initialValue: _role,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: tr(context, 'Роль в проекте'),
                              ),
                              items: [
                                for (final role in cubit.state.invitationRoles)
                                  DropdownMenuItem(
                                    value: role,
                                    child: Text(
                                      memberRoleLabel(role),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _sending
                                  ? null
                                  : (value) => setState(() => _role = value!),
                            ),
                            const SizedBox(height: AppSpacing.mdLg),
                            FilledButton(
                              key: const Key('participants_add_submit'),
                              onPressed: _sending || duplicate ? null : _submit,
                              child: Text(
                                _sending
                                    ? tr(context, 'Отправка…')
                                    : _selected == null
                                    ? tr(context, 'Пригласить по email')
                                    : tr(context, 'Добавить участника'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_sending) return;
    final email = (_selected?.email ?? _query.text).trim().toLowerCase();
    if (!isInvitationEmail(email)) {
      setState(() {
        _invalidEmail = true;
        _error = 'Введите корректный email или выберите пользователя.';
      });
      return;
    }
    final cubit = context.read<ProjectParticipantsCubit>();
    if (cubit.state.members.any((m) => m.email.toLowerCase() == email) ||
        cubit.state.invitations.any((m) => m.email.toLowerCase() == email)) {
      setState(
        () => _error = 'Доступ уже предоставлен или приглашение отправлено.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final success = await cubit.mutate(
      () => cubit.repository.add(cubit.id, email, _role),
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _sending = false;
        _error = cubit.state.error ?? 'Не удалось отправить приглашение.';
      });
    }
  }
}

class _ProjectLink extends StatefulWidget {
  const _ProjectLink({
    required this.cubit,
    required this.roles,
    required this.enabled,
    super.key,
  });
  final ProjectParticipantsCubit cubit;
  final List<String> roles;
  final bool enabled;
  @override
  State<_ProjectLink> createState() => _ProjectLinkState();
}

class _ProjectLinkState extends State<_ProjectLink> {
  ProjectAccessLink? _link;
  bool _busy = true;
  String? _error;
  String _role = 'EXECUTOR';
  @override
  void initState() {
    super.initState();
    _perform(() => widget.cubit.repository.link(widget.cubit.id));
  }

  Future<void> _perform(Future<ProjectAccessLink?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await action();
      if (mounted) {
        setState(() {
          _link = link;
          _role = link?.role ?? 'EXECUTOR';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = widget.cubit.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && widget.enabled;
    final canShare = enabled && _error == null && widget.roles.contains(_role);
    final theme = Theme.of(context);
    final border = BorderSide(color: theme.colorScheme.outlineVariant);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: border,
    );
    return ParticipantsSectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.link,
                size: AppIconSizes.standard,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tr(context, 'Ссылка на доску'),
                  style: AppTypography.title(context),
                ),
              ),
              if (_link != null && _error == null)
                const ParticipantBadge('Активна', accent: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(context, 'Для проекта и подпроектов'),
            style: AppTypography.caption(
              context,
            )?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              tr(context, _error!),
              style: AppTypography.body(
                context,
              )?.copyWith(color: theme.colorScheme.error),
            ),
            TextButton.icon(
              key: const Key('participants_link_retry'),
              onPressed: _busy
                  ? null
                  : () => _perform(
                      () => widget.cubit.repository.link(widget.cubit.id),
                    ),
              icon: const Icon(
                LucideIcons.rotateCw,
                size: AppIconSizes.standard,
              ),
              label: Text(tr(context, 'Повторить')),
            ),
          ],
          DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.colorScheme.surface,
              shape: controlShape,
            ),
            child: AppActionMenuButton<String>(
              key: const Key('participants_link_role'),
              title: tr(context, 'Роль по ссылке'),
              tooltip: tr(context, 'Изменить роль по ссылке'),
              enabled: enabled && _error == null,
              groups: [
                [
                  for (final role in widget.roles)
                    AppMenuAction(
                      value: role,
                      label: memberRoleLabel(role),
                      icon: LucideIcons.shield,
                      selected: role == _role,
                    ),
                ],
              ],
              onSelected: (value) {
                if (_link == null) {
                  setState(() => _role = value);
                } else {
                  _perform(
                    () => widget.cubit.repository.changeLinkRole(
                      widget.cubit.id,
                      value,
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.smMd),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'Роль по ссылке'),
                          style: AppTypography.body(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          memberRoleLabel(_role),
                          textAlign: TextAlign.end,
                          style: AppTypography.body(context)?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(
                        LucideIcons.chevronDown,
                        size: AppIconSizes.standard,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.smMd),
          if (_link != null) ...[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: theme.colorScheme.surface,
                shape: controlShape,
              ),
              child: Tooltip(
                message: _link!.url,
                child: InkWell(
                  key: const Key('participants_link_open'),
                  onTap: canShare ? _open : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Semantics(
                    label: tr(context, "Открыть ссылку: {p0}", {
                      'p0': _link!.url,
                    }),
                    button: true,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.smMd),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _link!.url.replaceFirst(
                                RegExp(r'^https?://'),
                                '',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            LucideIcons.externalLink,
                            size: AppIconSizes.standard,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ParticipantsLinkActions(
              copy: FilledButton.icon(
                key: const Key('participants_link_copy'),
                onPressed: canShare ? _copy : null,
                icon: const Icon(LucideIcons.copy, size: AppIconSizes.standard),
                label: Text(tr(context, 'Копировать')),
              ),
              share: Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  key: const Key('participants_link_share'),
                  onPressed: canShare ? () => _share(buttonContext) : null,
                  icon: const Icon(
                    LucideIcons.share2,
                    size: AppIconSizes.standard,
                  ),
                  label: Text(tr(context, 'Поделиться')),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('participants_link_revoke'),
                onPressed: enabled ? _revoke : null,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(tr(context, 'Отключить ссылку')),
              ),
            ),
          ] else if (_error == null && !_busy)
            FilledButton.icon(
              key: const Key('participants_link_create'),
              onPressed: enabled
                  ? () => _perform(
                      () => widget.cubit.repository.createLink(
                        widget.cubit.id,
                        _role,
                      ),
                    )
                  : null,
              icon: const Icon(LucideIcons.link, size: AppIconSizes.standard),
              label: Text(tr(context, 'Создать ссылку')),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              context,
              'Роль применяется к новому доступу. Существующие права сохраняются.',
            ),
            style: AppTypography.caption(
              context,
            )?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link!.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.success,
          content: Text(tr(context, 'Ссылка скопирована')),
        ),
      );
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    try {
      final box = buttonContext.findRenderObject() as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          text: _link!.url,
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(tr(context, 'Не удалось открыть меню «Поделиться».')),
          ),
        );
      }
    }
  }

  Future<void> _open() async {
    try {
      if (!await launchUrl(
        Uri.parse(_link!.url),
        mode: LaunchMode.externalApplication,
      )) {
        throw const FormatException();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(tr(context, 'Не удалось открыть ссылку.')),
          ),
        );
      }
    }
  }

  Future<void> _revoke() async {
    if (!await showAppConfirmation(
      context,
      tr(context, 'Отключить ссылку?'),
      tr(
        context,
        'Старая ссылка перестанет предоставлять доступ. Участники сохранят существующие права.',
      ),
      confirmLabel: 'Отключить',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    await _perform(() async {
      await widget.cubit.repository.revokeLink(widget.cubit.id);
      return null;
    });
  }
}

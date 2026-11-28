import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cached_svg_image.dart';
import '../../domain/entities/workspace_model.dart';
import '../cubit/workspace_cubit.dart';
import '../cubit/workspace_state.dart';

class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final hostContext = context;
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, state) {
        final cubit = context.read<WorkspaceCubit>();
        final loaded = state is WorkspaceLoaded ? state : null;
        final colors = AppColors.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return FTheme(
          data: isDark ? FTheme.neutral.dark.touch : FTheme.neutral.light.touch,
          child: FPopover(
            popoverAnchor: Alignment.topLeft,
            childAnchor: Alignment.bottomLeft,
            spacing: const FPortalSpacing(6),
            popoverClipBehavior: Clip.antiAlias,
            style: FPopoverStyle(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F212A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? colors.border : const Color(0xFFE5E8F0),
                ),
                boxShadow: isDark
                    ? const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x160F172A),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              popoverPadding: EdgeInsets.zero,
            ),
            popoverBuilder: (_, controller) =>
                BlocBuilder<WorkspaceCubit, WorkspaceState>(
                  bloc: cubit,
                  builder: (_, liveState) => _WorkspacePopoverContent(
                    hostContext: hostContext,
                    state: liveState,
                    cubit: cubit,
                    controller: controller,
                    onCreate: () => _create(hostContext, cubit),
                    onArchived: () => _archived(hostContext, cubit),
                  ),
                ),
            builder: (context, controller, _) => Tooltip(
              message: tr(context, 'Переключить workspace'),
              child: InkWell(
                key: const Key('workspace-switcher'),
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  controller.toggle();
                  unawaited(cubit.load(force: true));
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          loaded == null
                              ? tr(context, 'Рабочие пространства')
                              : loaded.allSelected ||
                                    (loaded.areAllSelected &&
                                        loaded.workspaces.length > 1)
                              ? tr(context, 'Все воркспейсы')
                              : loaded.effectiveSelectedIds.length > 1
                              ? tr(context, 'Рабочие пространства')
                              : loaded.selected?.name ??
                                    tr(context, 'Рабочие пространства'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: colors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _create(BuildContext context, WorkspaceCubit cubit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _CreateWorkspace()),
    );
  }

  Future<void> _archived(BuildContext context, WorkspaceCubit cubit) async {
    unawaited(cubit.loadArchived());
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocBuilder<WorkspaceCubit, WorkspaceState>(
        bloc: cubit,
        builder: (context, state) {
          final loaded = state is WorkspaceLoaded ? state : null;
          final colors = AppColors.of(context);
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      tr(context, 'Архивированные'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  if (loaded?.isLoadingArchived == true)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  if (loaded?.archivedError != null)
                    ListTile(
                      title: Text(
                        loaded!.archivedError!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colors.error,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: tr(context, 'Повторить'),
                        onPressed: cubit.loadArchived,
                        icon: Icon(LucideIcons.refreshCw, color: colors.ink),
                      ),
                    ),
                  if (loaded != null &&
                      !loaded.isLoadingArchived &&
                      loaded.archivedError == null &&
                      loaded.archivedWorkspaces.isEmpty)
                    ListTile(
                      title: Text(
                        tr(context, 'Нет архивированных workspace'),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  for (final workspace
                      in loaded?.archivedWorkspaces ?? const <WorkspaceModel>[])
                    ListTile(
                      leading: _WorkspaceAvatar(workspace: workspace, size: 32),
                      title: Text(
                        workspace.name.trim().isEmpty
                            ? tr(context, 'Без названия')
                            : workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorkspacePopoverContent extends StatelessWidget {
  const _WorkspacePopoverContent({
    required this.hostContext,
    required this.state,
    required this.cubit,
    required this.controller,
    required this.onCreate,
    required this.onArchived,
  });

  final BuildContext hostContext;
  final WorkspaceState state;
  final WorkspaceCubit cubit;
  final FPopoverController controller;
  final VoidCallback onCreate;
  final VoidCallback onArchived;

  @override
  Widget build(BuildContext context) {
    final loaded = state is WorkspaceLoaded ? state as WorkspaceLoaded : null;
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width <= 24
        ? viewport.width
        : math.min(288.0, viewport.width - 24);
    final maxHeight = viewport.height * 0.62;
    final dividerColor = isDark
        ? colors.border.withValues(alpha: 0.7)
        : const Color(0xFFF0F2F7);
    final allChecked =
        loaded != null &&
        loaded.workspaces.isNotEmpty &&
        (loaded.allSelected ||
            (loaded.areAllSelected && loaded.workspaces.length > 1));

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Рабочие пространства').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: colors.muted,
                        ),
                      ),
                    ),
                    if (loaded != null && loaded.workspaces.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.outgoingMessage,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${loaded.effectiveSelectedIds.length}/${loaded.workspaces.length}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loaded != null && loaded.workspaces.isNotEmpty) ...[
                        _WorkspaceOptionRow(
                          key: const Key('workspace-select-all'),
                          label: tr(context, 'Все'),
                          selected: allChecked,
                          leading: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: allChecked
                                  ? colors.accent
                                  : (isDark
                                        ? colors.badgeSurface
                                        : const Color(0xFFF1F3F8)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.layoutGrid,
                              size: 15,
                              color: allChecked
                                  ? colors.onAccent
                                  : colors.muted,
                            ),
                          ),
                          onTap: () => unawaited(cubit.selectAll()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: dividerColor,
                          ),
                        ),
                      ],
                      for (final workspace
                          in loaded?.workspaces ?? const <WorkspaceModel>[])
                        _WorkspaceOptionRow(
                          label: workspace.name.trim().isEmpty
                              ? tr(context, 'Без названия')
                              : workspace.name,
                          selected: loaded!.effectiveSelectedIds.contains(
                            workspace.id,
                          ),
                          leading: _WorkspaceAvatar(
                            workspace: workspace,
                            size: 28,
                          ),
                          onTap: () {
                            unawaited(cubit.toggle(workspace));
                            final router = GoRouter.maybeOf(hostContext);
                            if (router != null &&
                                router.routeInformationProvider.value.uri.path
                                    .startsWith('/projects/')) {
                              router.go('/projects');
                            }
                          },
                        ),
                      if (loaded != null && loaded.workspaces.isEmpty)
                        _WorkspaceStatusNotice(
                          icon: LucideIcons.folderOpen,
                          text: tr(context, 'Доступных workspace пока нет'),
                          color: colors.muted,
                        ),
                      if (loaded == null)
                        _WorkspaceStatusNotice(
                          icon: state is WorkspaceFailure
                              ? LucideIcons.circleAlert
                              : LucideIcons.loaderCircle,
                          text: tr(
                            context,
                            state is WorkspaceFailure
                                ? (state as WorkspaceFailure).message
                                : 'Загрузка…',
                          ),
                          color: state is WorkspaceFailure
                              ? colors.error
                              : colors.muted,
                        ),
                      if (loaded?.refreshError != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.circleAlert,
                                size: 15,
                                color: colors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loaded!.refreshError!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: colors.error,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? colors.border : const Color(0xFFF0F2F7),
              ),
              Container(
                color: isDark
                    ? const Color(0xFF191B23)
                    : const Color(0xFFFAFBFD),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WorkspaceActionRow(
                      icon: LucideIcons.plus,
                      label: tr(context, 'Создать workspace'),
                      accent: true,
                      onTap: () {
                        controller.hide();
                        onCreate();
                      },
                    ),
                    const SizedBox(height: 2),
                    _WorkspaceActionRow(
                      icon: LucideIcons.archive,
                      label: tr(context, 'Архивированные'),
                      accent: false,
                      onTap: () {
                        controller.hide();
                        onArchived();
                      },
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
}

class _WorkspaceOptionRow extends StatelessWidget {
  const _WorkspaceOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? colors.outgoingMessage.withValues(alpha: 0.65)
                      : colors.outgoingMessage)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? colors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: selected
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? const Color(0xFF4B4E5F)
                                      : const Color(0xFFCBD2E1),
                                  width: 1.5,
                                ),
                        ),
                        child: selected
                            ? Icon(
                                LucideIcons.check,
                                size: 13,
                                color: colors.onAccent,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceActionRow extends StatelessWidget {
  const _WorkspaceActionRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent
                        ? colors.accent.withValues(alpha: isDark ? 0.22 : 0.11)
                        : (isDark
                              ? colors.badgeSurface
                              : const Color(0xFFF0F2F7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: accent ? colors.accent : colors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: accent ? FontWeight.w600 : FontWeight.w500,
                      color: accent ? colors.accent : colors.ink,
                    ),
                  ),
                ),
                if (!accent) ...[
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 15,
                    color: colors.muted.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceStatusNotice extends StatelessWidget {
  const _WorkspaceStatusNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceAvatar extends StatefulWidget {
  const _WorkspaceAvatar({required this.workspace, required this.size});

  final WorkspaceModel? workspace;
  final double size;

  @override
  State<_WorkspaceAvatar> createState() => _WorkspaceAvatarState();
}

class _WorkspaceAvatarState extends State<_WorkspaceAvatar> {
  static const _fallbackPalette = <Color>[
    Color(0xFF6D5FE0),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  Widget? _cachedNetworkLogo;
  String? _cachedLogoKey;

  @override
  void didUpdateWidget(_WorkspaceAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace?.logoUrl != widget.workspace?.logoUrl ||
        oldWidget.size != widget.size) {
      _cachedNetworkLogo = null;
      _cachedLogoKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _InitialWorkspaceBadge(
      workspace: widget.workspace,
      size: widget.size,
      baseColor: _resolveBaseColor(),
    );
    final logoUrl = widget.workspace?.logoUrl;
    if (logoUrl == null || logoUrl.isEmpty) {
      return fallback;
    }
    final cacheKey = '${widget.size}:$logoUrl';
    if (_cachedNetworkLogo == null || _cachedLogoKey != cacheKey) {
      _cachedLogoKey = cacheKey;
      _cachedNetworkLogo = _buildLogoWidget(logoUrl, fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _cachedNetworkLogo,
      ),
    );
  }

  Widget _buildLogoWidget(String logoUrl, Widget fallback) {
    final embedded = _embeddedImage(logoUrl, fallback);
    if (embedded != null) return embedded;

    final sameOrigin = ApiConstants.isSameOrigin(logoUrl);
    final token = sameOrigin && sl.isRegistered<AuthTokenStorage>()
        ? sl<AuthTokenStorage>().cachedToken
        : null;
    final headers = token == null || token.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $token'};

    if (_isSvg(logoUrl)) {
      return CachedSvgImage(
        url: logoUrl,
        headers: headers,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        fallback: fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: logoUrl,
      httpHeaders: headers,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  Widget? _embeddedImage(String value, Widget fallback) {
    if (!value.startsWith('data:image/')) return null;
    final separator = value.indexOf(',');
    if (separator < 0) return fallback;
    try {
      final metadata = value.substring(0, separator).toLowerCase();
      final payload = value.substring(separator + 1);
      if (metadata.contains('image/svg+xml')) {
        final source = metadata.contains(';base64')
            ? utf8.decode(base64Decode(payload))
            : Uri.decodeComponent(payload);
        return SvgPicture.string(
          source,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        );
      }
      final bytes = metadata.contains(';base64')
          ? base64Decode(payload)
          : base64Decode(Uri.decodeComponent(payload));
      return Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  bool _isSvg(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.svg') ||
        url.toLowerCase().startsWith('data:image/svg+xml');
  }

  Color _resolveBaseColor() {
    var hex = widget.workspace?.color?.replaceFirst('#', '').trim();
    if (hex != null) {
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length == 6 || hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null) {
          return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
        }
      }
    }
    final seed = widget.workspace?.id ?? widget.workspace?.name ?? '';
    return _fallbackPalette[seed.hashCode.abs() % _fallbackPalette.length];
  }
}

class _InitialWorkspaceBadge extends StatelessWidget {
  const _InitialWorkspaceBadge({
    required this.workspace,
    required this.size,
    required this.baseColor,
  });

  final WorkspaceModel? workspace;
  final double size;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(baseColor);
    final letterColor = isDark
        ? hsl.withLightness(math.max(hsl.lightness, 0.72)).toColor()
        : hsl.withLightness(math.min(hsl.lightness, 0.42)).toColor();
    final name = workspace?.name.trim() ?? '';
    final initial = name.isEmpty ? 'W' : name.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: isDark ? 0.24 : 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: baseColor.withValues(alpha: isDark ? 0.35 : 0.24),
        ),
      ),
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w700,
          color: letterColor,
          height: 1,
        ),
      ),
    );
  }
}

class _CreateWorkspace extends StatefulWidget {
  const _CreateWorkspace();

  @override
  State<_CreateWorkspace> createState() => _CreateWorkspaceState();
}

class _CreateWorkspaceState extends State<_CreateWorkspace> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context.read<WorkspaceCubit>().createWorkspace(
      _name.text,
      '#6D5FE0',
    );
    if (mounted && saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          final loaded = state is WorkspaceLoaded ? state : null;
          final colors = AppColors.of(context);
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, 'Создать workspace'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    enabled: loaded?.isCreating != true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Название workspace'),
                    ),
                    onSubmitted: (_) {
                      if (loaded?.isCreating != true) _save();
                    },
                  ),
                  if (loaded?.creationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        loaded!.creationError!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: loaded?.isCreating == true ? null : _save,
                    child: Text(tr(context, 'Создать')),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

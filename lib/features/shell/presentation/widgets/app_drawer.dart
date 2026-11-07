import '../../../../core/theme/app_icon_sizes.dart';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../../workspaces/data/models/workspace_model.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _text = Color(0xFF2F333A);
  static const Color _muted = Color(0xFF737A86);
  static const Color _border = Color(0xFFDDE1E7);
  static const Color _purple = Color(0xFF6D5FE0);
  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: width,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(21, 20, 21, 16),
              child: _SectionLabel('ВОРКСПЕЙСЫ'),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('drawer-scroll-view'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: const _DrawerWorkspaces(),
              ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _SidebarItem(
                icon: LucideIcons.settings,
                iconColor: _muted,
                label: 'Настройки',
                onTap: onOpenSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerWorkspaces extends StatefulWidget {
  const _DrawerWorkspaces();

  @override
  State<_DrawerWorkspaces> createState() => _DrawerWorkspacesState();
}

class _DrawerWorkspacesState extends State<_DrawerWorkspaces> {
  bool _showCreateForm = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceCubit, WorkspaceState>(
      builder: (context, state) => _WorkspaceList(
        state: state,
        showCreateForm: _showCreateForm,
        onAdd: () => setState(() => _showCreateForm = true),
        onCancel: () => setState(() => _showCreateForm = false),
        onCreated: () => setState(() => _showCreateForm = false),
      ),
    );
  }
}

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({
    required this.state,
    required this.showCreateForm,
    required this.onAdd,
    required this.onCancel,
    required this.onCreated,
  });

  final WorkspaceState state;
  final bool showCreateForm;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final VoidCallback onCreated;

  @override
  Widget build(BuildContext context) {
    if (state is WorkspaceFailure) {
      final failure = state as WorkspaceFailure;
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                failure.message,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFFA53C35),
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.read<WorkspaceCubit>().load(force: true),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (state is! WorkspaceLoaded) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppDrawer._purple,
          ),
        ),
      );
    }
    final loaded = state as WorkspaceLoaded;
    return Material(
      color: AppDrawer._bg,
      child: Padding(
        key: const Key('drawer-workspaces-content'),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          children: [
            if (loaded.isRefreshing)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppDrawer._purple,
              ),
            if (loaded.refreshError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loaded.refreshError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDrawer._muted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Обновить workspace',
                      onPressed: () =>
                          context.read<WorkspaceCubit>().load(force: true),
                      icon: const Icon(
                        LucideIcons.refreshCw,
                        size: AppIconSizes.standard,
                      ),
                    ),
                  ],
                ),
              ),
            if (loaded.workspaces.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Доступных workspace пока нет',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppDrawer._muted,
                    ),
                  ),
                ),
              )
            else
              ...loaded.workspaces.map((workspace) {
                final isSelected = workspace.id == loaded.selected?.id;
                return _SidebarItem(
                  key: ValueKey('drawer-workspace-${workspace.id}'),
                  icon: LucideIcons.layers,
                  iconColor: AppDrawer._muted,
                  leading: _WorkspaceBadge(workspace: workspace, size: 28),
                  label: workspace.name.isEmpty
                      ? 'Без названия'
                      : workspace.name,
                  isActive: isSelected,
                  onTap: loaded.isCreating
                      ? null
                      : () => _selectWorkspace(context, workspace),
                );
              }),
            const Divider(height: 1, color: AppDrawer._border),
            if (showCreateForm)
              _CreateWorkspacePanel(
                loaded: loaded,
                onCancel: onCancel,
                onCreated: onCreated,
              )
            else
              _AddWorkspaceRow(onTap: onAdd),
            const Divider(height: 1, color: AppDrawer._border),
            const _ArchivedWorkspacesRow(),
          ],
        ),
      ),
    );
  }

  Future<void> _selectWorkspace(
    BuildContext context,
    WorkspaceModel workspace,
  ) async {
    final cubit = context.read<WorkspaceCubit>();
    final previous = cubit.state;
    final changed =
        previous is WorkspaceLoaded && previous.selected?.id != workspace.id;
    await cubit.select(workspace);
    if (!context.mounted) return;
    final current = cubit.state;
    if (current is! WorkspaceLoaded || current.selected?.id != workspace.id) {
      return;
    }
    final router = GoRouter.of(context);
    Scaffold.of(context).closeDrawer();
    if (changed &&
        router.routeInformationProvider.value.uri.path.startsWith(
          '/projects/',
        )) {
      router.go('/projects');
    }
  }
}

class _AddWorkspaceRow extends StatelessWidget {
  const _AddWorkspaceRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('add-workspace-row'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            const Icon(
              LucideIcons.plus,
              size: AppIconSizes.standard,
              color: Color(0xFF6D5FE0),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Добавить workspace',
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5F6475),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateWorkspacePanel extends StatefulWidget {
  const _CreateWorkspacePanel({
    required this.loaded,
    required this.onCancel,
    required this.onCreated,
  });

  final WorkspaceLoaded loaded;
  final VoidCallback onCancel;
  final VoidCallback onCreated;

  @override
  State<_CreateWorkspacePanel> createState() => _CreateWorkspacePanelState();
}

class _CreateWorkspacePanelState extends State<_CreateWorkspacePanel> {
  static const List<Color> _palette = <Color>[
    Color(0xFF6D5FE0),
    Color(0xFFE45D70),
    Color(0xFF3CAF78),
    Color(0xFFE3A25B),
    Color(0xFF3DABC3),
    Color(0xFFB65BD8),
    Color(0xFFC79732),
    Color(0xFF5EAAD2),
  ];

  final TextEditingController _nameController = TextEditingController();
  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = widget.loaded.isCreating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: TextField(
              key: const Key('workspace-name-field'),
              controller: _nameController,
              enabled: !isCreating,
              textInputAction: TextInputAction.done,
              onChanged: (_) =>
                  context.read<WorkspaceCubit>().clearCreationError(),
              onSubmitted: (_) => isCreating ? null : _submit(context),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppDrawer._text,
              ),
              decoration: InputDecoration(
                hintText: 'Название...',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 14,
                  color: const Color(0xFF9298A3),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: const Color(0xFFFCFCFB),
                border: _fieldBorder(Colors.transparent),
                enabledBorder: _fieldBorder(Colors.transparent),
                focusedBorder: _fieldBorder(const Color(0xFF6D5FE0)),
                disabledBorder: _fieldBorder(Colors.transparent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(_palette.length, (index) {
              final selected = index == _selectedColorIndex;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Цвет workspace ${index + 1}',
                child: InkWell(
                  key: Key('workspace-color-$index'),
                  onTap: isCreating
                      ? null
                      : () {
                          setState(() => _selectedColorIndex = index);
                          context.read<WorkspaceCubit>().clearCreationError();
                        },
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    width: 27,
                    height: 27,
                    padding: EdgeInsets.all(selected ? 3 : 0),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF262A35) : null,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isCreating
                            ? _palette[index].withValues(alpha: 0.55)
                            : _palette[index],
                        borderRadius: BorderRadius.circular(selected ? 2 : 5),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (widget.loaded.creationError != null) ...[
            const SizedBox(height: 7),
            Text(
              widget.loaded.creationError!,
              key: const Key('workspace-creation-error'),
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFA53C35),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const Key('create-workspace-button'),
                    onPressed: isCreating ? null : () => _submit(context),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF6D5FE0),
                      disabledBackgroundColor: const Color(0xFFD1CEF1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: isCreating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Создать'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextButton(
                    key: const Key('cancel-workspace-button'),
                    onPressed: isCreating ? null : _cancel,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F0F1),
                      foregroundColor: const Color(0xFF5F6475),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final color =
        '#${_palette[_selectedColorIndex].toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final created = await context.read<WorkspaceCubit>().createWorkspace(
      _nameController.text,
      color,
    );
    if (!mounted || !created) return;
    _nameController.clear();
    setState(() => _selectedColorIndex = 0);
    widget.onCreated();
  }

  void _cancel() {
    _nameController.clear();
    setState(() => _selectedColorIndex = 0);
    context.read<WorkspaceCubit>().clearCreationError();
    widget.onCancel();
  }
}

class _ArchivedWorkspacesRow extends StatefulWidget {
  const _ArchivedWorkspacesRow();
  @override
  State<_ArchivedWorkspacesRow> createState() => _ArchivedWorkspacesRowState();
}

class _ArchivedWorkspacesRowState extends State<_ArchivedWorkspacesRow> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          final loaded = state is WorkspaceLoaded ? state : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(
                  LucideIcons.archive,
                  size: AppIconSizes.standard,
                  color: AppDrawer._muted,
                ),
                title: Text(
                  'Архивированные',
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppDrawer._muted,
                  ),
                ),
                trailing: Icon(
                  _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: AppIconSizes.standard,
                  color: AppDrawer._muted,
                ),
                onTap: () {
                  setState(() => _expanded = !_expanded);
                  if (_expanded) context.read<WorkspaceCubit>().loadArchived();
                },
              ),
              if (_expanded && loaded != null) ...[
                if (loaded.isLoadingArchived)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (loaded.archivedError != null)
                  ListTile(
                    dense: true,
                    title: Text(
                      loaded.archivedError!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      tooltip: 'Повторить',
                      onPressed: () =>
                          context.read<WorkspaceCubit>().loadArchived(),
                      icon: const Icon(
                        LucideIcons.refreshCw,
                        size: AppIconSizes.standard,
                      ),
                    ),
                  ),
                if (!loaded.isLoadingArchived &&
                    loaded.archivedError == null &&
                    loaded.archivedWorkspaces.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Нет архивированных workspace',
                      style: TextStyle(fontSize: 12, color: AppDrawer._muted),
                    ),
                  ),
                if (loaded.archivedWorkspaces.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 144),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final workspace in loaded.archivedWorkspaces)
                          ListTile(
                            dense: true,
                            leading: _WorkspaceBadge(
                              workspace: workspace,
                              size: 28,
                            ),
                            title: Text(
                              workspace.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: AppDrawer._muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      );
}

class _WorkspaceBadge extends StatelessWidget {
  const _WorkspaceBadge({required this.workspace, required this.size});

  final WorkspaceModel? workspace;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logoUrl = workspace?.logoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final embeddedImage = _embeddedImage(logoUrl);
      if (embeddedImage != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: embeddedImage,
        );
      }

      final sameOrigin = Uri.tryParse(logoUrl)?.host == 'jospar.me';
      final token = sameOrigin && sl.isRegistered<AuthTokenStorage>()
          ? sl<AuthTokenStorage>().cachedToken
          : null;
      final headers = token == null || token.isEmpty
          ? null
          : <String, String>{'Authorization': 'Bearer $token'};

      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: _isSvg(logoUrl)
            ? SvgPicture.network(
                logoUrl,
                headers: headers,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => _initialBadge(),
                errorBuilder: (context, _, _) => _initialBadge(),
              )
            : CachedNetworkImage(
                imageUrl: logoUrl,
                httpHeaders: headers,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, _) => _initialBadge(),
                errorWidget: (context, _, _) => _initialBadge(),
              ),
      );
    }
    return _initialBadge();
  }

  Widget? _embeddedImage(String value) {
    if (!value.startsWith('data:image/')) return null;
    final separator = value.indexOf(',');
    if (separator < 0) return _initialBadge();

    try {
      final metadata = value.substring(0, separator).toLowerCase();
      final payload = value.substring(separator + 1);
      if (metadata.contains('image/svg+xml')) {
        final source = metadata.contains(';base64')
            ? utf8.decode(base64Decode(payload))
            : Uri.decodeComponent(payload);
        return SvgPicture.string(
          source,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }

      final bytes = metadata.contains(';base64')
          ? base64Decode(payload)
          : base64Decode(Uri.decodeComponent(payload));
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => _initialBadge(),
      );
    } catch (_) {
      return _initialBadge();
    }
  }

  bool _isSvg(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.svg') ||
        url.toLowerCase().startsWith('data:image/svg+xml');
  }

  Widget _initialBadge() {
    final name = workspace?.name.trim() ?? '';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _parseColor(workspace?.color),
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Text(
        name.isEmpty ? 'W' : name.characters.first.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }

  Color _parseColor(String? value) {
    final hex = value?.replaceFirst('#', '').trim();
    if (hex == null || (hex.length != 6 && hex.length != 8)) {
      return const Color(0xFF38B973);
    }
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return const Color(0xFF38B973);
    return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppDrawer._muted,
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.leading,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isActive
              ? AppDrawer._purple.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            child: Row(
              children: [
                leading ??
                    Icon(
                      icon,
                      size: AppIconSizes.standard,
                      color: isActive ? AppDrawer._purple : iconColor,
                    ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppDrawer._purple : AppDrawer._text,
                    ),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    LucideIcons.check,
                    size: AppIconSizes.standard,
                    color: AppDrawer._purple,
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

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
import '../../../projects/data/models/project_model.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../../projects/presentation/cubit/projects_state.dart';
import '../../../workspaces/data/models/workspace_model.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onCreateProject});

  final Future<void> Function() onCreateProject;

  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _text = Color(0xFF2F333A);
  static const Color _muted = Color(0xFF737A86);
  static const Color _border = Color(0xFFDDE1E7);
  static const Color _purple = Color(0xFF7C70BC);
  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: width,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('drawer-scroll-view'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _WorkspaceHeader(),
              _DrawerProjects(onCreateProject: onCreateProject),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerProjects extends StatelessWidget {
  const _DrawerProjects({required this.onCreateProject});

  final Future<void> Function() onCreateProject;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        if (state.isLoading && state.projects.isEmpty) {
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

        final pinned = state.projects
            .where((project) => project.isPinned)
            .toList(growable: false);
        final regular = state.projects
            .where((project) => !project.isPinned)
            .toList(growable: false);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: Column(
            key: const Key('drawer-projects-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('ЗАКРЕПЛЕНО'),
              const SizedBox(height: 6),
              if (pinned.isEmpty)
                const _EmptyDrawerSection('Нет закреплённых проектов')
              else
                ...pinned.map(
                  (project) => _ProjectDrawerItem(
                    project: project,
                    isActive: project.id == state.selectedProjectId,
                    icon: LucideIcons.pin,
                    iconColor: AppDrawer._purple,
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppDrawer._border),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: _SectionLabel('ПРОЕКТЫ')),
                  InkWell(
                    key: const Key('create-project-button'),
                    onTap: () => _createProject(context),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        LucideIcons.plus,
                        size: 16,
                        color: AppDrawer._muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (state.errorMessage != null && state.projects.isEmpty)
                _DrawerProjectsError(
                  message: state.errorMessage!,
                  onRetry: state.workspaceId == null
                      ? null
                      : () => context.read<ProjectsCubit>().loadForWorkspace(
                          state.workspaceId!,
                        ),
                )
              else if (regular.isEmpty)
                const _EmptyDrawerSection('В этом workspace нет проектов')
              else
                ...regular.map(
                  (project) => _ProjectDrawerItem(
                    project: project,
                    isActive: project.id == state.selectedProjectId,
                    icon: LucideIcons.folder,
                    iconColor: AppDrawer._muted,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static void _openProjects(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/projects');
  }

  Future<void> _createProject(BuildContext context) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await onCreateProject();
  }
}

class _ProjectDrawerItem extends StatelessWidget {
  const _ProjectDrawerItem({
    required this.project,
    required this.isActive,
    required this.icon,
    required this.iconColor,
  });

  final ProjectModel project;
  final bool isActive;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _SidebarItem(
      icon: icon,
      iconColor: iconColor,
      label: project.name.isEmpty ? project.code : project.name,
      isActive: isActive,
      onTap: () {
        context.read<ProjectsCubit>().selectProject(project.id);
        _DrawerProjects._openProjects(context);
      },
    );
  }
}

class _EmptyDrawerSection extends StatelessWidget {
  const _EmptyDrawerSection(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppDrawer._muted,
        ),
      ),
    );
  }
}

class _DrawerProjectsError extends StatelessWidget {
  const _DrawerProjectsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: const Color(0xFFA53C35),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatefulWidget {
  const _WorkspaceHeader();

  @override
  State<_WorkspaceHeader> createState() => _WorkspaceHeaderState();
}

class _WorkspaceHeaderState extends State<_WorkspaceHeader> {
  bool _isExpanded = false;
  bool _showCreateForm = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppDrawer._border)),
      ),
      child: BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          final loaded = state is WorkspaceLoaded ? state : null;
          final selected = loaded?.selected;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: state is WorkspaceLoading
                    ? null
                    : () => setState(() {
                        _isExpanded = !_isExpanded;
                        if (!_isExpanded) _showCreateForm = false;
                      }),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      if (state is WorkspaceLoading)
                        const SizedBox.square(
                          dimension: 28,
                          child: Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppDrawer._purple,
                            ),
                          ),
                        )
                      else
                        _WorkspaceBadge(workspace: selected, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _headerTitle(state),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppDrawer._text,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: AppDrawer._muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: _isExpanded
                    ? _WorkspaceDropdown(
                        state: state,
                        showCreateForm: _showCreateForm,
                        onAdd: () => setState(() => _showCreateForm = true),
                        onCancel: () => setState(() => _showCreateForm = false),
                        onCreated: () =>
                            setState(() => _showCreateForm = false),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          );
        },
      ),
    );
  }

  String _headerTitle(WorkspaceState state) {
    if (state is WorkspaceLoaded) {
      return state.selected?.name ?? 'Нет workspace';
    }
    if (state is WorkspaceFailure) return 'Workspace';
    return 'Загрузка...';
  }
}

class _WorkspaceDropdown extends StatelessWidget {
  const _WorkspaceDropdown({
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

    if (state is! WorkspaceLoaded) return const SizedBox.shrink();
    final loaded = state as WorkspaceLoaded;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppDrawer._border)),
      ),
      child: Column(
        children: [
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
              return InkWell(
                onTap: loaded.isCreating
                    ? null
                    : () => context.read<WorkspaceCubit>().select(workspace),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
                  child: Row(
                    children: [
                      _WorkspaceBadge(workspace: workspace, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          workspace.name.isEmpty
                              ? 'Без названия'
                              : workspace.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppDrawer._text,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          LucideIcons.check,
                          size: 18,
                          color: Color(0xFF635BEB),
                        ),
                    ],
                  ),
                ),
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
    );
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
            const Icon(LucideIcons.plus, size: 18, color: Color(0xFF6D5FE0)),
            const SizedBox(width: 10),
            Text(
              'Добавить workspace',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5F6475),
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
                border: _fieldBorder(const Color(0xFFD6D8D6)),
                enabledBorder: _fieldBorder(const Color(0xFFD6D8D6)),
                focusedBorder: _fieldBorder(const Color(0xFF6D5FE0), 1.5),
                disabledBorder: _fieldBorder(const Color(0xFFE3E4E6)),
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
                      backgroundColor: const Color(0xFFAAA3ED),
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

class _ArchivedWorkspacesRow extends StatelessWidget {
  const _ArchivedWorkspacesRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Раздел появится позже',
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const Icon(
                LucideIcons.archive,
                size: 17,
                color: Color(0xFF858AA1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Архивированные',
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF777C91),
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronDown,
                size: 15,
                color: Color(0xFF858AA1),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

      final token = sl<AuthTokenStorage>().cachedToken;
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
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

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
                Icon(
                  icon,
                  size: 18,
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
                    size: 16,
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

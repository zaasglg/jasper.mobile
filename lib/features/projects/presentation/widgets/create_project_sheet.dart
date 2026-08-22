import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../workspaces/data/models/workspace_model.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../../data/models/create_project_request.dart';
import '../cubit/projects_cubit.dart';
import '../cubit/projects_state.dart';

const _ink = Color(0xFF20222D);
const _secondary = Color(0xFF666B80);
const _muted = Color(0xFF989DA9);
const _border = Color(0xFFDADCE2);
const _surface = Color(0xFFFAFAF9);
const _accent = Color(0xFF6C5CE7);
const _danger = Color(0xFFB42318);

Future<void> showCreateProjectFlow(BuildContext context) async {
  final workspaceState = context.read<WorkspaceCubit>().state;
  if (workspaceState is! WorkspaceLoaded ||
      workspaceState.selected == null ||
      workspaceState.workspaces.isEmpty) {
    return;
  }

  final initialWorkspace = workspaceState.selected!;
  final projectsCubit = context.read<ProjectsCubit>();
  final workspaceCubit = context.read<WorkspaceCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final createdInWorkspace = await showModalBottomSheet<WorkspaceModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: _ink.withValues(alpha: 0.36),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider<ProjectsCubit>.value(
      value: projectsCubit,
      child: CreateProjectSheet(
        workspaces: workspaceState.workspaces,
        initialWorkspace: initialWorkspace,
      ),
    ),
  );

  if (createdInWorkspace == null || !context.mounted) return;
  if (createdInWorkspace.id != initialWorkspace.id) {
    await workspaceCubit.select(createdInWorkspace);
    if (!context.mounted) return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Проект создан',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class CreateProjectSheet extends StatefulWidget {
  const CreateProjectSheet({
    super.key,
    required this.workspaces,
    required this.initialWorkspace,
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel initialWorkspace;

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late WorkspaceModel _workspace;
  DateTime? _start;
  DateTime? _end;
  bool _showDateErrors = false;

  @override
  void initState() {
    super.initState();
    _workspace = widget.initialWorkspace;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = isStart ? (_start ?? today) : (_end ?? _start ?? today);
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Дата начала' : 'Дата окончания',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = value;
        if (_end != null && _end!.isBefore(value)) _end = value;
      } else {
        _end = value;
      }
      _showDateErrors = false;
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final validFields = _formKey.currentState?.validate() ?? false;
    setState(() => _showDateErrors = true);
    if (!validFields || _start == null || _end == null) return;
    if (_end!.isBefore(_start!)) return;

    final success = await context.read<ProjectsCubit>().createProject(
      CreateProjectRequest(
        code: _generateProjectCode(),
        name: _nameController.text,
        description: _descriptionController.text,
        workspaceId: _workspace.id,
        start: _start!,
        end: _end!,
        progress: 0,
        isPinned: false,
      ),
    );
    if (success && mounted) Navigator.of(context).pop(_workspace);
  }

  String _generateProjectCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final suffix = timestamp.length > 8
        ? timestamp.substring(timestamp.length - 8)
        : timestamp.padLeft(8, '0');
    return 'PRJ-$suffix';
  }

  void _close() => Navigator.of(context).pop<WorkspaceModel>();

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return BlocBuilder<ProjectsCubit, ProjectsState>(
      builder: (context, state) {
        final disabled = state.isCreating;
        return PopScope(
          canPop: !disabled,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SheetHeader(disabled: disabled, onClose: _close),
                  const Divider(height: 1, color: _border),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _LabeledTextField(
                              key: const Key('project_name_field'),
                              controller: _nameController,
                              label: 'Название',
                              required: true,
                              hint: 'Портал госуслуг 2.0',
                              enabled: !disabled,
                              textInputAction: TextInputAction.next,
                              validator: _required('Укажите название'),
                            ),
                            const SizedBox(height: 16),
                            _WorkspaceField(
                              workspaces: widget.workspaces,
                              selected: _workspace,
                              enabled: !disabled,
                              onChanged: (workspace) {
                                if (workspace == null) return;
                                setState(() => _workspace = workspace);
                              },
                            ),
                            const SizedBox(height: 16),
                            _LabeledTextField(
                              key: const Key('project_description_field'),
                              controller: _descriptionController,
                              label: 'Описание',
                              hint: 'Краткое описание проекта...',
                              enabled: !disabled,
                              minLines: 3,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: _DateField(
                                    key: const Key('project_start_field'),
                                    label: 'Начало',
                                    date: _start,
                                    enabled: !disabled,
                                    error: _showDateErrors && _start == null
                                        ? 'Выберите дату'
                                        : null,
                                    onTap: () => _pickDate(isStart: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DateField(
                                    key: const Key('project_end_field'),
                                    label: 'Окончание',
                                    date: _end,
                                    enabled: !disabled,
                                    error: _showDateErrors && _end == null
                                        ? 'Выберите дату'
                                        : _showDateErrors &&
                                              _start != null &&
                                              _end != null &&
                                              _end!.isBefore(_start!)
                                        ? 'Раньше начала'
                                        : null,
                                    onTap: () => _pickDate(isStart: false),
                                  ),
                                ),
                              ],
                            ),
                            if (state.creationError
                                case final error?) ...<Widget>[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: error),
                            ],
                            const SizedBox(height: 24),
                            _FooterActions(
                              isCreating: disabled,
                              onCancel: _close,
                              onSubmit: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String? Function(String?) _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.disabled, required this.onClose});

  final bool disabled;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(LucideIcons.folder, size: 21, color: _accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Новый проект',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Закрыть',
            onPressed: disabled ? null : onClose,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(44),
              side: const BorderSide(color: _border),
              foregroundColor: _secondary,
              disabledForegroundColor: _muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(LucideIcons.x, size: 20),
          ),
        ],
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    this.required = false,
    this.validator,
    this.minLines,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final bool required;
  final String? Function(String?)? validator;
  final int? minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          validator: validator,
          style: GoogleFonts.manrope(fontSize: 15, color: _ink),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: _danger),
            ),
        ],
      ),
      maxLines: 2,
      style: GoogleFonts.manrope(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: _secondary,
      ),
    );
  }
}

class _WorkspaceField extends StatelessWidget {
  const _WorkspaceField({
    required this.workspaces,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel selected;
  final bool enabled;
  final ValueChanged<WorkspaceModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = workspaces.any((workspace) => workspace.id == selected.id)
        ? workspaces
        : <WorkspaceModel>[selected, ...workspaces];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _FieldLabel(label: 'Workspace'),
        const SizedBox(height: 7),
        DropdownButtonFormField<WorkspaceModel>(
          key: const Key('project_workspace_dropdown'),
          initialValue: selected,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 18),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          style: GoogleFonts.manrope(fontSize: 15, color: _ink),
          decoration: _inputDecoration(),
          onChanged: enabled ? onChanged : null,
          selectedItemBuilder: (context) => items
              .map((workspace) => _WorkspaceOption(workspace: workspace))
              .toList(growable: false),
          items: items
              .map(
                (workspace) => DropdownMenuItem<WorkspaceModel>(
                  value: workspace,
                  child: _WorkspaceOption(workspace: workspace),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _WorkspaceOption extends StatelessWidget {
  const _WorkspaceOption({required this.workspace});

  final WorkspaceModel workspace;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _WorkspaceMark(workspace: workspace),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            workspace.name.isEmpty ? 'Без названия' : workspace.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceMark extends StatelessWidget {
  const _WorkspaceMark({required this.workspace});

  final WorkspaceModel workspace;

  @override
  Widget build(BuildContext context) {
    final name = workspace.name.trim();
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _parseWorkspaceColor(workspace.color),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        name.isEmpty ? 'W' : name.characters.first.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.date,
    required this.enabled,
    required this.onTap,
    this.error,
  });

  final String label;
  final DateTime? date;
  final bool enabled;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final value = date == null ? 'ДД.ММ.ГГГГ' : _formatDate(date!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label: label, required: true),
        const SizedBox(height: 7),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: enabled ? _surface : const Color(0xFFF1F2F4),
              border: Border.all(color: error == null ? _border : _danger),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: date == null ? _muted : _ink,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.calendarDays,
                  size: 16,
                  color: _secondary,
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            error!,
            style: GoogleFonts.manrope(fontSize: 11, color: _danger),
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        border: Border.all(color: const Color(0xFFF4C7C2)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        message,
        style: GoogleFonts.manrope(fontSize: 13, color: _danger),
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.isCreating,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isCreating;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 320;
        final cancel = OutlinedButton(
          onPressed: isCreating ? null : onCancel,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(118, 52),
            foregroundColor: _secondary,
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Отмена'),
        );
        final submit = FilledButton(
          key: const Key('submit_project_button'),
          onPressed: isCreating ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size(184, 52),
            backgroundColor: _accent,
            disabledBackgroundColor: _accent.withValues(alpha: 0.55),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: isCreating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Создать проект'),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: double.infinity, child: submit),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: cancel),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            cancel,
            const SizedBox(width: 10),
            Flexible(child: submit),
          ],
        );
      },
    );
  }
}

InputDecoration _inputDecoration({String? hint}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    counterText: '',
    hintStyle: GoogleFonts.manrope(color: _muted),
    filled: true,
    fillColor: _surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: border(_border),
    enabledBorder: border(_border),
    disabledBorder: border(_border),
    focusedBorder: border(_accent, 1.5),
    errorBorder: border(_danger),
    focusedErrorBorder: border(_danger, 1.5),
    errorStyle: GoogleFonts.manrope(fontSize: 11, color: _danger),
  );
}

Color _parseWorkspaceColor(String? value) {
  final hex = value?.replaceFirst('#', '').trim();
  if (hex == null || (hex.length != 6 && hex.length != 8)) return _accent;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return _accent;
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../inbox/domain/entities/inbox_task_model.dart';
import '../../../projects/domain/entities/project_task_model.dart';

class PlannerTaskPicker extends StatefulWidget {
  const PlannerTaskPicker({
    super.key,
    required this.tasks,
    required this.inbox,
  });
  final List<ProjectTaskModel> tasks;
  final List<InboxTaskModel> inbox;
  @override
  State<PlannerTaskPicker> createState() => _PlannerTaskPickerState();
}

class _PlannerTaskPickerState extends State<PlannerTaskPicker> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _search.text.trim().toLowerCase();
    final height = (media.size.height * .82 - media.viewInsets.bottom).clamp(
      180.0,
      720.0,
    );
    final compact = height < 320;
    final all = [
      for (final task in widget.tasks)
        if (!task.archived)
          (
            value: task as Object,
            id: 'project-${task.id}',
            title: task.title,
            code: task.displayId,
            source: 'Проект',
            icon: LucideIcons.folder,
          ),
      for (final task in widget.inbox)
        if (!task.archived && !task.isLocalOnly)
          (
            value: task as Object,
            id: 'inbox-${task.id}',
            title: task.title,
            code: task.displayId,
            source: 'Инбокс',
            icon: LucideIcons.inbox,
          ),
    ];
    final visible = all
        .where(
          (task) => '${task.title} ${task.code} ${task.source}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    final neutral = dark ? const Color(0xFF242424) : const Color(0xFFF7F7F7);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'Выберите задачу'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 4),
                            Text(
                              tr(context, "Из проектов или инбокса · {p0}", {
                                'p0': all.length,
                              }),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('planner-task-picker-close'),
                      tooltip: tr(context, 'Закрыть выбор задачи'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  key: const Key('planner-task-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: tr(context, 'Название или номер задачи'),
                    filled: true,
                    fillColor: neutral,
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: tr(context, 'Очистить поиск'),
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(LucideIcons.x, size: 16),
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .5),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                query.isEmpty
                                    ? LucideIcons.inbox
                                    : LucideIcons.search,
                                size: 28,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                query.isEmpty
                                    ? tr(context, 'Нет доступных задач')
                                    : tr(context, 'Ничего не найдено'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                query.isEmpty
                                    ? tr(
                                        context,
                                        'Задачи из проектов и инбокса появятся здесь.',
                                      )
                                    : tr(
                                        context,
                                        'Попробуйте другое название или номер.',
                                      ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 62,
                          endIndent: 16,
                          color: colors.outlineVariant.withValues(alpha: .35),
                        ),
                        itemBuilder: (context, index) {
                          final task = visible[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey('planner-pick-${task.id}'),
                              onTap: () => Navigator.pop(context, task.value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: neutral,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        task.icon,
                                        size: 18,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title.trim().isEmpty
                                                ? tr(context, 'Без названия')
                                                : task.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                              color: colors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            task.code.isEmpty
                                                ? task.source
                                                : '${task.code} · ${task.source}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      LucideIcons.plus,
                                      size: 18,
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

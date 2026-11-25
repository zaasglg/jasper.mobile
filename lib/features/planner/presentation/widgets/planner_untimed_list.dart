import 'package:jospar/core/localization/app_translations.dart';
import 'planner_task_symbol.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../data/models/planner_item_model.dart';

class PlannerUntimedList extends StatelessWidget {
  const PlannerUntimedList({
    super.key,
    required this.items,
    required this.busyIds,
    required this.onAssign,
    required this.onMenu,
    required this.onToggle,
    this.enableDrag = false,
  });
  final List<PlannerItemModel> items;
  final bool enableDrag;
  final Set<String> busyIds;
  final ValueChanged<PlannerItemModel> onAssign, onMenu, onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            6,
          ),
          child: Row(
            children: [
              Text(
                tr(context, 'Весь день'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.of(context).muted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.of(context).outgoingMessage,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${items.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final item = items[index];
              final busy = busyIds.contains(item.id);
              final card = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 232),
                child: Material(
                  color: item.completed
                      ? AppColors.of(context).subtleSurface
                      : AppColors.of(context).chatCanvas,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: busy ? null : () => onToggle(item),
                        tooltip: item.completed
                            ? tr(context, 'Вернуть в план')
                            : tr(context, 'Отметить в ежедневнике'),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(34, 40),
                          minimumSize: const Size(34, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                        icon: PlannerTaskSymbol(
                          item: item,
                          busy: busy,
                          size: 18,
                        ),
                      ),
                      Flexible(
                        child: InkWell(
                          key: ValueKey('planner-unscheduled-${item.id}'),
                          onTap: busy ? null : () => onAssign(item),
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 40,
                            child: Center(
                              widthFactor: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Text(
                                  item.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: item.completed
                                        ? AppColors.of(context).muted
                                        : AppColors.of(context).ink,
                                    decoration: item.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('planner-item-menu-${item.id}'),
                        onPressed: busy ? null : () => onMenu(item),
                        tooltip: tr(context, 'Действия записи'),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(32, 40),
                          minimumSize: const Size(32, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          LucideIcons.ellipsis,
                          size: 16,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (!enableDrag || busy || item.external) return card;
              return LongPressDraggable<PlannerItemModel>(
                key: ValueKey('planner-untimed-drag-${item.id}'),
                data: item,
                maxSimultaneousDrags: 1,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  elevation: 6,
                  color: AppColors.of(context).chatCanvas,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          PlannerTaskSymbol(item: item, busy: false, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.of(context).ink,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: .35, child: card),
                child: card,
              );
            },
          ),
        ),
      ],
    ),
  );
}

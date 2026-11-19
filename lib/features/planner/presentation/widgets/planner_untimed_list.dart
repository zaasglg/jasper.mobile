import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/planner_item_model.dart';

class PlannerUntimedList extends StatelessWidget {
  const PlannerUntimedList({
    super.key,
    required this.items,
    required this.busyIds,
    required this.onAssign,
    required this.onMenu,
    required this.onToggle,
  });
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final ValueChanged<PlannerItemModel> onAssign, onMenu, onToggle;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .3,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Без времени · ${items.length}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            primary: false,
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              final busy = busyIds.contains(item.id);
              return Row(
                children: [
                  IconButton(
                    onPressed: busy ? null : () => onToggle(item),
                    tooltip: item.completed
                        ? 'Вернуть в план'
                        : 'Отметить в ежедневнике',
                    icon: Icon(
                      item.completed
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      size: 20,
                      color: item.completed
                          ? AppColors.accent
                          : AppColors.muted,
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      key: ValueKey('planner-unscheduled-${item.id}'),
                      onTap: busy ? null : () => onAssign(item),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: item.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.plannedDate == null
                                  ? 'Без даты · Выбрать день'
                                  : 'Назначить время',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('planner-item-menu-${item.id}'),
                    onPressed: busy ? null : () => onMenu(item),
                    tooltip: 'Действия записи',
                    icon: const Icon(LucideIcons.ellipsis, size: 20),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/widgets/task_completion_indicator.dart';
import '../../data/models/planner_item_model.dart';
import '../../domain/repositories/task_icon_repository.dart';
import '../cubit/planner_cubit.dart';

const plannerTaskSymbols = {
  'alarm': (icon: LucideIcons.alarmClock, color: Color(0xFFE7A09B)),
  'exercise': (icon: LucideIcons.dumbbell, color: Color(0xFF638BA4)),
  'shower': (icon: LucideIcons.showerHead, color: Color(0xFF39748C)),
  'coffee': (icon: LucideIcons.coffee, color: Color(0xFFA05476)),
  'bike': (icon: LucideIcons.bike, color: Color(0xFF93B66B)),
  'call': (icon: LucideIcons.phone, color: Color(0xFF718DB3)),
  'meeting': (icon: LucideIcons.users, color: Color(0xFF8E80AD)),
  'code': (icon: LucideIcons.code, color: Color(0xFF568F90)),
  'document': (icon: LucideIcons.fileText, color: Color(0xFFBA9566)),
  'study': (icon: LucideIcons.graduationCap, color: Color(0xFF788BB3)),
  'shopping': (icon: LucideIcons.shoppingBag, color: Color(0xFFB97B92)),
  'meal': (icon: LucideIcons.utensils, color: Color(0xFFBC956C)),
  'travel': (icon: LucideIcons.plane, color: Color(0xFF6B9AA7)),
  'home': (icon: LucideIcons.house, color: Color(0xFF8E9B72)),
  'task': (icon: LucideIcons.listTodo, color: Color(0xFF8A93A2)),
};

const plannerIconLabels = {
  'alarm': 'Будильник',
  'exercise': 'Тренировка',
  'shower': 'Душ',
  'coffee': 'Кофе',
  'bike': 'Велосипед',
  'call': 'Звонок',
  'meeting': 'Встреча',
  'code': 'Код',
  'document': 'Документ',
  'study': 'Учёба',
  'shopping': 'Покупки',
  'meal': 'Еда',
  'travel': 'Поездка',
  'home': 'Дом',
  'task': 'Задача',
};

({IconData icon, Color color}) plannerTaskSymbol(
  BuildContext context,
  PlannerItemModel item,
) {
  final automatic = context.select<PlannerCubit?, String?>(
    (cubit) => cubit?.state.taskIcons[plannerIconTitle(item.title)],
  );
  return plannerTaskSymbols[item.icon ?? automatic] ??
      plannerTaskSymbols['task']!;
}

class PlannerTaskSymbol extends StatelessWidget {
  const PlannerTaskSymbol({
    super.key,
    required this.item,
    required this.busy,
    this.size = 20,
    this.onFilledBackground = false,
  });
  final PlannerItemModel item;
  final bool busy;
  final double size;
  final bool onFilledBackground;

  @override
  Widget build(BuildContext context) {
    final symbol = plannerTaskSymbol(context, item);
    if (busy || item.completed) {
      return TaskCompletionIndicator(
        completed: item.completed,
        busy: busy,
        size: size,
      );
    }
    return Icon(
      symbol.icon,
      size: size,
      color: onFilledBackground ? Colors.white : symbol.color,
    );
  }
}

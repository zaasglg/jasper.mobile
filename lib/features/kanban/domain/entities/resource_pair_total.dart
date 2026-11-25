import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../../../tasks/domain/entities/task_resource_model.dart';

class ResourcePairTotal extends Equatable {
  const ResourcePairTotal({
    required this.planName,
    required this.factName,
    required this.plan,
    required this.fact,
  });

  final String planName;
  final String factName;
  final double plan;
  final double fact;
  double get percentage => plan > 0 ? math.max(0, fact / plan * 100) : 0;
  double get progress => (percentage / 100).clamp(0, 1);

  factory ResourcePairTotal.fromJson(Map<String, dynamic> json) =>
      ResourcePairTotal(
        planName: json['planName'] as String,
        factName: json['factName'] as String,
        plan: (json['plan'] as num).toDouble(),
        fact: (json['fact'] as num).toDouble(),
      );
  Map<String, dynamic> toJson() => {
    'planName': planName,
    'factName': factName,
    'plan': plan,
    'fact': fact,
  };
  ResourcePairTotal copyWith({
    String? planName,
    String? factName,
    double? plan,
    double? fact,
  }) => ResourcePairTotal(
    planName: planName ?? this.planName,
    factName: factName ?? this.factName,
    plan: plan ?? this.plan,
    fact: fact ?? this.fact,
  );
  @override
  List<Object?> get props => [planName, factName, plan, fact];
}

/// Pairs adjacent resources *within each task*, then groups by both exact names.
List<ResourcePairTotal> summarizeTaskResourcePairs(
  Iterable<List<TaskResourceModel>> tasks, {
  String planFallback = 'План',
  String factFallback = 'Факт',
}) {
  final totals = <(String, String), ResourcePairTotal>{};
  for (final resources in tasks) {
    final ordered = resources.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.order.compareTo(b.$2.order);
        return order == 0 ? a.$1.compareTo(b.$1) : order;
      });
    for (var i = 0; i + 1 < ordered.length; i += 2) {
      final top = ordered[i].$2;
      final bottom = ordered[i + 1].$2;
      final planName = top.name.trim().isEmpty ? planFallback : top.name.trim();
      final factName = bottom.name.trim().isEmpty
          ? factFallback
          : bottom.name.trim();
      final key = (planName, factName);
      final previous = totals[key];
      final plan = (previous?.plan ?? 0) + top.planValue;
      final fact = (previous?.fact ?? 0) + bottom.factValue;
      if (!plan.isFinite || !fact.isFinite) {
        throw const FormatException('Invalid resource totals');
      }
      totals[key] = ResourcePairTotal(
        planName: planName,
        factName: factName,
        plan: plan,
        fact: fact,
      );
    }
  }
  return List.unmodifiable(totals.values);
}

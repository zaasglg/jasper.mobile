import 'package:equatable/equatable.dart';
import '../../data/models/planner_item_model.dart';

enum PlannerStatus { initial, loading, success, failure }

class PlannerState extends Equatable {
  const PlannerState({
    this.workspaceId = '',
    this.status = PlannerStatus.initial,
    this.items = const [],
    this.busyIds = const {},
    this.error,
    this.actionError,
    this.actionRevision = 0,
    this.isSaving = false,
  });
  final String workspaceId;
  final PlannerStatus status;
  final List<PlannerItemModel> items;
  final Set<String> busyIds;
  final String? error, actionError;
  final int actionRevision;
  final bool isSaving;
  PlannerState copyWith({
    PlannerStatus? status,
    List<PlannerItemModel>? items,
    Set<String>? busyIds,
    String? error,
    String? actionError,
    int? actionRevision,
    bool? isSaving,
    bool clearError = false,
  }) => PlannerState(
    workspaceId: workspaceId,
    status: status ?? this.status,
    items: items ?? this.items,
    busyIds: busyIds ?? this.busyIds,
    error: clearError ? null : error ?? this.error,
    actionError: actionError ?? this.actionError,
    actionRevision: actionRevision ?? this.actionRevision,
    isSaving: isSaving ?? this.isSaving,
  );
  @override
  List<Object?> get props => [
    workspaceId,
    status,
    items,
    busyIds,
    error,
    actionError,
    actionRevision,
    isSaving,
  ];
}

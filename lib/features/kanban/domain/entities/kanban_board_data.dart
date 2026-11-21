import '../../../projects/domain/entities/project_task_model.dart';
import 'package:equatable/equatable.dart';

import '../../../tasks/domain/entities/kanban_column_model.dart';

class KanbanBoardData extends Equatable {
  const KanbanBoardData({required this.columns, required this.tasks});

  final List<KanbanColumnModel> columns;
  final List<ProjectTaskModel> tasks;

  @override
  List<Object?> get props => <Object?>[columns, tasks];
}

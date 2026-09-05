import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';
import 'package:jospar/features/tasks/presentation/cubit/my_tasks_state.dart';

void main() {
  test('resolves a configured column before using status fallbacks', () {
    const task = ProjectTaskModel(
      id: 'task',
      projectId: 'project',
      status: 'TODO',
    );
    const configured = MyTasksState(
      columnsByProjectId: <String, List<KanbanColumnModel>>{
        'project': <KanbanColumnModel>[
          KanbanColumnModel(id: 'custom', name: 'В планах', statusMap: 'TODO'),
        ],
      },
    );

    expect(configured.columnName(task), 'В планах');
    expect(
      const MyTasksState().columnName(task.copyWith(status: 'REVIEW')),
      'На проверке',
    );
    expect(
      const MyTasksState().columnName(task.copyWith(status: 'UNKNOWN')),
      '—',
    );
  });
}

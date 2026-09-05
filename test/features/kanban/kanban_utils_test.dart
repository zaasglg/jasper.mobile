import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/kanban/domain/utils/kanban_utils.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';

void main() {
  const todo = KanbanColumnModel(
    id: 'todo',
    name: 'К работе',
    statusMap: 'TODO',
    order: 2,
  );
  const progress = KanbanColumnModel(
    id: 'progress',
    name: 'В работе',
    statusMap: 'PROGRESS',
    order: 1,
  );

  test('sorts columns by order', () {
    expect(sortKanbanColumns(const [todo, progress]), const [progress, todo]);
  });

  test('groups tasks by column statusMap and sorts by order', () {
    final grouped = groupKanbanTasks(
      const [todo, progress],
      const [
        ProjectTaskModel(id: '2', projectId: 'p', status: 'TODO', order: 2),
        ProjectTaskModel(id: '1', projectId: 'p', status: 'TODO', order: 1),
      ],
    );
    expect(grouped['TODO']!.map((task) => task.id), ['1', '2']);
  });

  test('moves a task inside the same column', () {
    final moved = moveKanbanTask(
      tasks: const [
        ProjectTaskModel(id: '1', projectId: 'p', status: 'TODO', order: 0),
        ProjectTaskModel(id: '2', projectId: 'p', status: 'TODO', order: 1),
      ],
      taskId: '2',
      projectId: 'p',
      targetStatus: 'TODO',
      targetPosition: 0,
    );
    final grouped = groupKanbanTasks(const [todo], moved);
    expect(grouped['TODO']!.map((task) => task.id), ['2', '1']);
  });

  test('moves a task between columns', () {
    final moved = moveKanbanTask(
      tasks: const [ProjectTaskModel(id: '1', projectId: 'p', status: 'TODO')],
      taskId: '1',
      projectId: 'p',
      targetStatus: 'PROGRESS',
      targetPosition: 0,
    );
    expect(moved.single.status, 'PROGRESS');
  });
}

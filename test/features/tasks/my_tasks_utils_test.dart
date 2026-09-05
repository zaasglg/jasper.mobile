import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/domain/utils/my_tasks_utils.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  test('detects only unfinished tasks with a past deadline as overdue', () {
    expect(isTaskOverdue(_task('overdue', DateTime(2026, 9, 3)), now), isTrue);
    expect(
      isTaskOverdue(_task('done', DateTime(2026, 9, 3), progress: 100), now),
      isFalse,
    );
    expect(isTaskOverdue(_task('future', DateTime(2026, 9, 5)), now), isFalse);
    expect(isTaskOverdue(_task('none', null), now), isFalse);
  });

  test('sort keeps overdue, current, and no-deadline groups in that order', () {
    final tasks = <ProjectTaskModel>[
      _task('none', null),
      _task('future-late', DateTime(2026, 9, 8)),
      _task('overdue-late', DateTime(2026, 9, 2)),
      _task('future-early', DateTime(2026, 9, 5)),
      _task('overdue-early', DateTime(2026, 9, 1)),
    ];

    expect(
      sortTasksByDeadline(tasks, ascending: true, now: now).map((t) => t.id),
      <String>[
        'overdue-early',
        'overdue-late',
        'future-early',
        'future-late',
        'none',
      ],
    );
    expect(
      sortTasksByDeadline(tasks, ascending: false, now: now).map((t) => t.id),
      <String>[
        'overdue-late',
        'overdue-early',
        'future-late',
        'future-early',
        'none',
      ],
    );
  });

  test('filters tasks by selected project ids', () {
    final tasks = <ProjectTaskModel>[
      _task('one', null, projectId: 'p1'),
      _task('two', null, projectId: 'p2'),
    ];

    expect(
      filterTasksByProjectIds(tasks, <String>{'p2'}).map((task) => task.id),
      <String>['two'],
    );
    expect(filterTasksByProjectIds(tasks, const <String>{}), tasks);
  });
}

ProjectTaskModel _task(
  String id,
  DateTime? end, {
  String projectId = 'project',
  double? progress,
}) {
  return ProjectTaskModel(
    id: id,
    displayId: id,
    title: id,
    projectId: projectId,
    status: 'TODO',
    progress: progress,
    end: end,
  );
}

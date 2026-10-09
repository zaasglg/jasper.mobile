import 'package:flutter/material.dart';
import 'package:jospar/features/tasks/data/models/task_label_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_cubit.dart';
import 'package:jospar/features/kanban/presentation/cubit/kanban_state.dart';
import 'package:jospar/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:jospar/features/kanban/domain/utils/kanban_utils.dart';
import 'package:jospar/features/projects/data/models/project_model.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/kanban_column_model.dart';

class _BoardCubit extends Cubit<KanbanState> implements KanbanCubit {
  _BoardCubit()
    : super(
        const KanbanState(
          projectId: 'p',
          columns: [
            KanbanColumnModel(
              id: 'c',
              name: 'Задачи',
              statusMap: 'TODO',
              order: 0,
            ),
            KanbanColumnModel(
              id: 'done',
              name: 'Готово',
              statusMap: 'DONE',
              order: 1,
            ),
          ],
          tasks: [
            ProjectTaskModel(
              id: 'a',
              title: 'Первая задача',
              fileCount: 2,
              checklistTotal: 4,
              checklistCompleted: 2,
              commentCount: 3,
              epics: [
                TaskEpicModel(
                  id: 'epic',
                  name: 'Архитектура',
                  color: '#26855c',
                ),
              ],
              labels: [
                TaskLabelModel(
                  id: 'label',
                  text: 'Личная метка',
                  isPersonal: true,
                  color: '#6366F1',
                ),
              ],
              projectId: 'p',
              status: 'TODO',
              order: 0,
            ),
            ProjectTaskModel(
              id: 'b',
              title: 'Вторая задача',
              projectId: 'p',
              status: 'TODO',
              order: 1,
            ),
            ProjectTaskModel(
              id: 'c',
              title: 'Третья задача',
              projectId: 'p',
              status: 'TODO',
              order: 2,
            ),
          ],
        ),
      );
  final moves = <int>[];
  final archived = <String>[];
  @override
  Future<void> archiveTask(ProjectTaskModel task) async {
    archived.add(task.id);
    emit(
      state.copyWith(
        tasks: state.tasks.where((item) => item.id != task.id).toList(),
      ),
    );
  }

  @override
  Future<void> moveTask(
    ProjectTaskModel task,
    String status,
    int position,
  ) async {
    moves.add(position);
    emit(
      state.copyWith(
        tasks: moveKanbanTask(
          tasks: state.tasks,
          taskId: task.id,
          projectId: 'p',
          targetStatus: status,
          targetPosition: position,
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'drag keeps width and opens an animated gap before saving the new position',
    (tester) async {
      final semantics = tester.ensureSemantics();
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = _BoardCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<KanbanCubit>.value(
              value: cubit,
              child: const KanbanBoard(
                project: ProjectModel(
                  id: 'p',
                  code: 'P',
                  name: 'Проект',
                  workspaceId: 'w',
                  start: null,
                  end: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Вложения: 2')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Обсуждения: 3')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Чек-лист: 2 из 4')), findsOneWidget);
      semantics.dispose();
      expect(find.text('Архитектура'), findsOneWidget);
      expect(find.text('Личная метка'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('task-actions-a')));
      await tester.pumpAndSettle();
      for (final label in [
        'Обложка',
        'Редактировать',
        'Дублировать',
        'Переместить',
        'Поделиться',
        'Копировать ссылку',
        'Перевести задачу',
        'Архивировать',
        'Удалить задачу',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Переместить задачу'), findsNothing);
      await tester.tap(find.text('Дублировать'));
      await tester.pumpAndSettle();
      expect(cubit.moves, isEmpty);
      expect(cubit.archived, isEmpty);
      final first = find.byKey(const ValueKey('a'));
      final second = find.byKey(const ValueKey('b'));
      final width = tester.getSize(first).width;
      final secondY = tester.getTopLeft(second).dy;
      final start = tester.getCenter(first);
      final target = tester.getCenter(find.byKey(const ValueKey('c')));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Архив'), findsOneWidget);
      for (var step = 1; step <= 12; step++) {
        await gesture.moveTo(Offset.lerp(start, target, step / 12)!);
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(first).width, closeTo(width, 0.1));
      expect(tester.getTopLeft(second).dy, lessThan(secondY));
      expect(cubit.moves, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(cubit.moves, [2]);
      expect(
        cubit.state.tasksFor(cubit.state.columns.first).map((task) => task.id),
        ['b', 'c', 'a'],
      );
      final upStart = tester.getCenter(first);
      final upTarget = tester.getTopLeft(second) + const Offset(80, 12);
      final upward = await tester.startGesture(upStart);
      await tester.pump(const Duration(milliseconds: 600));
      for (var step = 1; step <= 12; step++) {
        await upward.moveTo(Offset.lerp(upStart, upTarget, step / 12)!);
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await upward.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(first).width, closeTo(width, 0.1));
      await upward.up();
      await tester.pumpAndSettle();
      expect(cubit.moves, [2, 0]);
      expect(
        cubit.state.tasksFor(cubit.state.columns.first).map((task) => task.id),
        ['a', 'b', 'c'],
      );
      final moveDrag = await tester.startGesture(tester.getCenter(first));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Архив'), findsOneWidget);
      await moveDrag.moveTo(tester.getCenter(find.text('Переместить')));
      await tester.pump(const Duration(milliseconds: 200));
      final rightPosition = tester.getCenter(first);
      final moveTarget = tester.getCenter(find.text('Переместить'));
      final archiveTarget = tester.getCenter(find.text('Архив'));
      await moveDrag.moveTo(archiveTarget);
      await tester.pump(const Duration(milliseconds: 200));
      final leftPosition = tester.getCenter(first);
      expect(
        rightPosition.dx - leftPosition.dx,
        closeTo(moveTarget.dx - archiveTarget.dx, 1),
      );
      expect(tester.getSize(first).width, closeTo(width, 0.1));
      await moveDrag.moveTo(moveTarget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getCenter(first).dx, closeTo(rightPosition.dx, 1));
      await moveDrag.up();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Переместить задачу'), findsOneWidget);
      expect(cubit.moves, [2, 0]);
      Navigator.of(tester.element(find.text('Переместить задачу'))).pop();
      await tester.pumpAndSettle();
      expect(cubit.moves, [2, 0]);
      final archiveDrag = await tester.startGesture(tester.getCenter(first));
      await tester.pump(const Duration(milliseconds: 600));
      await archiveDrag.moveTo(tester.getCenter(find.text('Архив')));
      await tester.pump(const Duration(milliseconds: 200));
      await archiveDrag.up();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(cubit.archived, ['a']);
      expect(find.text('Первая задача'), findsNothing);
      expect(cubit.moves, [2, 0]);
      final changeColumn = await tester.startGesture(tester.getCenter(second));
      await tester.pump(const Duration(milliseconds: 600));
      await changeColumn.moveTo(tester.getCenter(find.text('Переместить')));
      await tester.pump(const Duration(milliseconds: 200));
      await changeColumn.up();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Готово').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Переместить'));
      await tester.pumpAndSettle();
      expect(
        cubit.state.tasks.firstWhere((task) => task.id == 'b').status,
        'DONE',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

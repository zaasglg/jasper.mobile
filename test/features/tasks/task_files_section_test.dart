import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_files_section.dart';

void main() {
  testWidgets(
    'list and grid keep preview targets and metadata, upload remains available',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TaskFileModel? opened;
      var added = false;
      var grid = false;
      final files = [
        TaskFileModel(
          id: 'image',
          name: 'cover.png',
          type: 'image/png',
          size: 2048,
          uploadedByName: 'Алия',
          uploadedAt: DateTime(2026, 10, 31),
        ),
        const TaskFileModel(
          id: 'pdf',
          name: 'file-sample_150kB.pdf',
          size: 150000,
          type: 'application/pdf',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Column(
                  children: [
                    TaskFilesViewToggle(
                      grid: grid,
                      onChanged: (value) => setState(() => grid = value),
                    ),
                    TaskFilesSection(
                      grid: grid,
                      files: files,
                      uploading: false,
                      onAdd: () => added = true,
                      onOpen: (file) => opened = file,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ListTile), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('task-file-pdf')));
      expect(opened?.id, 'pdf');
      await tester.tap(find.byTooltip('Файлы сеткой'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-files-grid')), findsOneWidget);
      expect(find.text('cover.png'), findsOneWidget);
      expect(find.textContaining('Алия'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('task-file-image')));
      expect(opened?.id, 'image');
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('task-add-files')));
      await tester.tap(find.byKey(const Key('task-add-files')));
      expect(added, true);
      await tester.tap(find.byTooltip('Файлы списком'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(2));
    },
  );
}

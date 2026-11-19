import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/tasks/presentation/screens/task_details_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/projects/data/models/project_task_model.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/data/models/task_location_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_relationships.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_rich_description.dart';
import 'task_test_app.dart';

const attachment = TaskFileModel(
  id: 'draft',
  name: 'plan.pdf',
  size: 2,
  type: 'application/pdf',
  dataUrl: 'data:application/pdf;base64,SGk=',
);
void main() {
  testWidgets(
    'description retains edited draft after failed save and retries',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = true;
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TaskRichDescriptionEditor(
                      initial: '<p>Было</p>',
                      onSave: (_) async => !fail,
                    ),
                  );
                },
                child: const Text('Редактировать'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новый текст');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Не удалось сохранить описание'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Новый текст',
      );
      expect(result, isNull);
      fail = false;
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(result, '<p>Новый текст</p>');
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'comment attachments and text survive failed send and clear after retry',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final original = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _Picker();
      addTearDown(() => FilePickerPlatform.instance = original);
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final adapter = _Adapter();
      final cubit = TaskDetailsCubit(_repo(adapter), _Profile());
      await tester.runAsync(() => cubit.load('task'));
      await tester.pumpWidget(
        TaskTestApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 'task'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.text('Обсуждение');
      await tester.scrollUntilVisible(
        section,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pumpAndSettle();
      final attach = find.byTooltip('Прикрепить файлы к комментарию');
      await tester.ensureVisible(attach);
      await tester.tap(attach);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Файлы').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'report.txt'), findsOneWidget);
      final field = find.widgetWithText(TextField, 'Написать комментарий…');
      await tester.enterText(field, 'Текст с файлом');
      adapter.fail = true;
      final send = find.byTooltip('Отправить');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Текст с файлом',
      );
      expect(find.widgetWithText(InputChip, 'report.txt'), findsOneWidget);
      adapter.fail = false;
      await tester.tap(send);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.byType(InputChip), findsNothing);
      expect(
        cubit.state.detail.comments.single.files.single.name,
        'report.txt',
      );
      expect(find.text('report.txt'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );

  test(
    'start and dependencies use website DTOs; null explicitly clears start',
    () async {
      final adapter = _Adapter();
      final repo = _repo(adapter);
      await repo.updateStart('task', DateTime.utc(2026, 11, 1));
      expect(adapter.requests.last.data, {'start': '2026-11-01T00:00:00.000Z'});
      await repo.updateStart('task', null);
      expect(adapter.requests.last.data, {'start': null});
      final result = await repo.updateDependencies('task', ['PR-2', 'PR-2']);
      expect(adapter.requests.last.data, {
        'deps': ['PR-2'],
      });
      expect(result.task.deps, ['PR-2']);
      expect(
        ProjectTaskModel.fromJson(
          result.task.toJson(),
        ).copyWith(title: 'Changed').deps,
        ['PR-2'],
      );
    },
  );
  test(
    'location save preserves other web detail fields and supports removal',
    () async {
      final adapter = _Adapter();
      final cubit = TaskDetailsCubit(_repo(adapter), _Profile());
      await cubit.load('task');
      final location = TaskLocationModel(
        address: 'Алматы',
        latitude: 43.2,
        longitude: 76.9,
      );
      expect(await cubit.updateLocation(location.toJson()), isTrue);
      expect(cubit.state.detail.raw['custom'], {'keep': true});
      expect(
        TaskLocationModel.parse(cubit.state.detail.raw['location']),
        location,
      );
      expect(await cubit.updateLocation(null), isTrue);
      expect(cubit.state.detail.toJson()['location'], isNull);
      expect(cubit.state.detail.description, '<p>Описание</p>');
      await cubit.close();
    },
  );
  test(
    'comments with files use atomic endpoint, server author and IDs, no whole detail patch',
    () async {
      final adapter = _Adapter();
      final cubit = TaskDetailsCubit(_repo(adapter), _Profile());
      await cubit.load('task');
      adapter.requests.clear();
      expect(await cubit.addComment('', files: [attachment]), isTrue);
      final request = adapter.requests.first;
      expect(request.path, 'project-tasks/task/comments');
      expect(request.method, 'POST');
      expect(request.data, {
        'text': '',
        'files': [
          {
            'name': 'plan.pdf',
            'dataUrl': attachment.dataUrl,
            'size': '2',
            'type': 'application/pdf',
          },
        ],
      });
      expect(adapter.requests.where((r) => r.method == 'PATCH'), isEmpty);
      final comment = cubit.state.detail.comments.single;
      expect(comment.id, 'server-comment');
      expect(comment.authorId, 'me');
      expect(comment.files.single.name, 'plan.pdf');
      expect(
        TaskCommentModel.fromJson(comment.toJson()).files.single.dataUrl,
        attachment.dataUrl,
      );
      adapter.fail = true;
      expect(await cubit.addComment('Retry', files: [attachment]), isFalse);
      expect(cubit.state.detail.comments.length, 1);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.actionErrorMessage, isNotNull);
      await cubit.close();
    },
  );
  test(
    'malformed locations fail validation, coordinate order stays longitude/latitude for Yandex',
    () {
      expect(
        TaskLocationModel.parse({
          'address': 'Place',
          'latitude': 'bad',
          'longitude': 10,
        }),
        isNull,
      );
      expect(
        TaskLocationModel.parse({
          'address': 'Place',
          'latitude': 91,
          'longitude': 10,
        }),
        isNull,
      );
      expect(
        TaskLocationModel.parse({'address': 'Place', 'latitude': 10}),
        isNull,
      );
      final place = TaskLocationModel.fromJson({
        'address': 'Place',
        'latitude': 43.2,
        'longitude': 76.9,
      });
      expect(place.link.queryParameters['ll'], '76.9,43.2');
      expect(
        TaskLocationModel.parse({'address': 'Address only'})!.valid,
        isTrue,
      );
    },
  );
  test('dependency selection detects direct, indirect and self cycles', () {
    const task = ProjectTaskModel(
      id: 'a',
      projectId: 'p',
      status: 'TODO',
      displayId: 'PR-1',
    );
    const first = ProjectTaskModel(
      id: 'b',
      projectId: 'p',
      status: 'TODO',
      displayId: 'PR-2',
      deps: ['PR-1'],
    );
    const second = ProjectTaskModel(
      id: 'c',
      projectId: 'p',
      status: 'TODO',
      displayId: 'PR-3',
      deps: ['PR-2'],
    );
    const other = ProjectTaskModel(
      id: 'd',
      projectId: 'p',
      status: 'TODO',
      displayId: 'PR-4',
    );
    final tasks = [task, first, second, other];
    expect(createsTaskDependencyCycle(task, task, tasks), isTrue);
    expect(createsTaskDependencyCycle(task, first, tasks), isTrue);
    expect(createsTaskDependencyCycle(task, second, tasks), isTrue);
    expect(createsTaskDependencyCycle(task, other, tasks), isFalse);
  });
  test(
    'rich HTML keeps formatting and tables, excludes executable markup and unsafe links',
    () {
      final clean = sanitizeTaskDescription(
        '<h2>T</h2><p onclick="bad()"><strong>B</strong><em>I</em><a href="javascript:bad()">X</a><a href="https://example.com">Safe</a></p><table><tr><td>Cell</td></tr></table><script>bad()</script><img src="x" onerror="bad()">',
      );
      expect(clean, contains('<strong>B</strong>'));
      expect(clean, contains('<td>Cell</td>'));
      expect(clean, contains('href="https://example.com"'));
      expect(clean, isNot(contains('javascript:')));
      expect(clean, isNot(contains('bad()')));
      final document = buildTaskDescriptionEditorHtml(
        '<p>Привет <strong>мир</strong></p>',
      );
      expect(document, isNot(contains('<p>Привет')));
      File('/tmp/jospar-description-editor.html').writeAsStringSync(document);
    },
  );
}

TaskDetailsRepositoryImpl _repo(_Adapter adapter) => TaskDetailsRepositoryImpl(
  Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
    ..httpClientAdapter = adapter,
);

class _Profile implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'me', name: 'Member', email: 'member@example.test');
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) => getCurrentUser();
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool fail = false;
  final task = <String, dynamic>{
    'id': 'task',
    'displayId': 'PR-1',
    'projectId': 'p',
    'status': 'TODO',
    'title': 'Task',
    'detail': {
      'description': '<p>Описание</p>',
      'custom': {'keep': true},
    },
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object data = task;
    if (options.path.endsWith('/history') || options.path == 'kanban-columns') {
      data = [];
    } else if (options.method == 'PATCH') {
      task.addAll(Map<String, dynamic>.from(options.data as Map));
    } else if (options.method == 'POST' && options.path.endsWith('/comments')) {
      data = {
        'id': 'server-comment',
        'author': 'Member',
        'authorId': 'me',
        'text': (options.data as Map)['text'],
        'files': (options.data as Map)['files'],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(fail ? {'message': 'Rejected'} : data),
      fail ? 403 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Picker extends FilePickerPlatform {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [_MemoryFile()];
}

final class _MemoryFile extends PlatformFile {
  @override
  String get name => 'report.txt';
  @override
  Future<int?> length() async => 2;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield Uint8List.fromList([72, 105]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

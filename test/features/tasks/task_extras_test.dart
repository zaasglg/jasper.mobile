import 'package:file_picker/file_picker.dart';
import 'package:jospar/features/tasks/data/services/task_file_picker.dart';
import 'package:jospar/core/widgets/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/tasks/presentation/screens/task_details_screen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';

void main() {
  testWidgets(
    'task menu edits labels through the real detail save flow on a narrow screen',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = _ExtrasAdapter()),
        _Profile(),
      );
      addTearDown(cubit.close);
      await tester.runAsync(() => cubit.load('t'));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 't'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Действия задачи'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Метки и личные метки'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить метку').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AppDialog),
              matching: find.byType(TextField),
            )
            .first,
        'Новая метка',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(cubit.state.detail.labels.single.text, 'Новая метка');
      expect(find.text('Новая метка'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'personal labels are user scoped, preserve other users and roll back errors',
    () async {
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await cubit.load('t');
      expect(
        await cubit.updatePersonalLabels(const [
          TaskLabelModel(id: 'l', text: 'Моя метка'),
        ]),
        true,
      );
      final personal = cubit.state.detail.raw['personalLabels'] as Map;
      expect(personal['other'], [
        {'id': 'private', 'text': 'Чужая метка'},
      ]);
      expect(cubit.state.visibleLabels.map((e) => e.text), ['Моя метка']);
      expect(cubit.state.task!.labelsForUser('me').map((e) => e.text), [
        'Моя метка',
      ]);
      expect(cubit.state.detail.raw['unknown'], {'retained': true});
      adapter.fail = true;
      expect(
        await cubit.updateLabels(const [
          TaskLabelModel(id: 'bad', text: 'Не сохранено'),
        ]),
        false,
      );
      expect(cubit.state.detail.labels, isEmpty);
      expect(cubit.state.detail.raw['personalLabels'], personal);
      expect(cubit.state.isSaving, false);
    },
  );
  testWidgets(
    'task Files section uploads through backend, keeps detail and rolls back rejected upload',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final original = FilePickerPlatform.instance;
      final picker = _Picker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await tester.runAsync(() => cubit.load('t'));
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TaskDetailsScreen(taskId: 't'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('task-add-files'));
      await tester.scrollUntilVisible(
        button,
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.detail.files.length, 2);
      final added = cubit.state.detail.files.last;
      expect(added.name, 'report.txt');
      expect(added.dataUrl, 'data:text/plain;base64,SGk=');
      expect(added.size, 2);
      expect(cubit.state.detail.description, 'Описание');
      expect(cubit.state.detail.raw['unknown'], {'retained': true});
      expect(adapter.lastPath, 'project-tasks/t/history');
      expect(adapter.detail['files'], hasLength(2));
      adapter.fail = true;
      ScaffoldMessenger.of(tester.element(button)).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.detail.files.length, 2);
      expect(cubit.state.actionErrorMessage, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'task file picker handles cancellation and refuses oversized streams',
    () async {
      final original = FilePickerPlatform.instance;
      final picker = _Picker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = original);
      picker.files = [];
      expect(await TaskFilePicker.pick(), isEmpty);
      picker.files = [_MemoryFile(oversized: true)];
      await expectLater(TaskFilePicker.pick(), throwsA(isA<Exception>()));
    },
  );
  test(
    'files persist alongside existing detail and removal clears only their cover reference',
    () async {
      final adapter = _ExtrasAdapter();
      final cubit = TaskDetailsCubit(
        TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = adapter),
        _Profile(),
      );
      addTearDown(cubit.close);
      await cubit.load('t');
      expect(
        await cubit.addFiles(const [
          TaskFileModel(
            id: 'added',
            name: 'test.txt',
            dataUrl: 'data:text/plain;base64,WA==',
          ),
        ]),
        true,
      );
      expect(cubit.state.detail.files.map((e) => e.id), ['cover', 'added']);
      expect(await cubit.removeFile('cover'), true);
      expect(cubit.state.detail.files.single.id, 'added');
      expect(cubit.state.detail.raw['cover'], isNull);
      expect(cubit.state.detail.description, 'Описание');
      expect(cubit.state.detail.raw['personalLabels'], {
        'other': [
          {'id': 'private', 'text': 'Чужая метка'},
        ],
      });
    },
  );
  test(
    'epic and resource updates match server DTOs without overwriting task fields',
    () async {
      final adapter = _ExtrasAdapter();
      final repo = TaskDetailsRepositoryImpl(
        Dio()..httpClientAdapter = adapter,
      );
      await repo.updateEpics('t', ['e']);
      expect(adapter.lastData, {
        'epicIds': ['e'],
      });
      await repo.saveResource(
        't',
        const TaskResourceModel(
          id: 'r',
          name: 'Бюджет',
          planValue: 100,
          factValue: 10,
          order: 3,
        ),
        create: true,
      );
      expect(adapter.lastPath, 'tasks/t/resources');
      expect(adapter.lastData, {
        'name': 'Бюджет',
        'planValue': '100.0',
        'factValue': '10.0',
      });
      await repo.saveResource(
        't',
        const TaskResourceModel(id: 'r', name: 'Бюджет'),
        create: false,
      );
      expect(adapter.lastPath, 'resources/r');
      await repo.deleteResource('r');
      expect(adapter.lastPath, 'resources/r');
    },
  );
}

class _Profile implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'me', name: 'Имя', email: 'me@example.test');
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) => getCurrentUser();
}

class _ExtrasAdapter implements HttpClientAdapter {
  bool fail = false;
  String? lastPath;
  dynamic lastData;
  Map<String, dynamic> detail = {
    'description': 'Описание',
    'unknown': {'retained': true},
    'personalLabels': {
      'other': [
        {'id': 'private', 'text': 'Чужая метка'},
      ],
    },
    'cover': {'type': 'image', 'fileId': 'cover'},
    'files': [
      {'id': 'cover', 'name': 'cover.png'},
    ],
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    lastPath = options.path;
    lastData = options.data;
    if (fail && options.method != 'GET') return _json({}, 403);
    if (options.path.endsWith('/history') ||
        options.path == 'kanban-columns' ||
        options.path == 'epics') {
      return _json([]);
    }
    if (options.method == 'PATCH' &&
        options.data is Map &&
        (options.data as Map).containsKey('detail')) {
      detail = Map<String, dynamic>.from(
        (options.data as Map)['detail'] as Map,
      );
    }
    return _json({
      'id': 't',
      'title': 'Задача',
      'projectId': 'p',
      'detail': detail,
    });
  }

  ResponseBody _json(Object value, [int code = 200]) => ResponseBody.fromString(
    jsonEncode(value),
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _Picker extends FilePickerPlatform {
  List<PlatformFile> files = [_MemoryFile()];
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
  }) async => files;
}

final class _MemoryFile extends PlatformFile {
  _MemoryFile({this.oversized = false});
  final bool oversized;
  @override
  String get name => 'report.txt';
  @override
  Future<int?> length() async => null;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield oversized
        ? Uint8List(TaskFilePicker.maxFileBytes + 1)
        : Uint8List.fromList([72, 105]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

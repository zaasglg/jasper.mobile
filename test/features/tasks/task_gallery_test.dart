import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/profile/data/models/user_profile.dart';
import 'package:jospar/features/profile/domain/repositories/profile_repository.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';
import 'package:jospar/features/tasks/data/repositories/task_details_repository_impl.dart';
import 'package:jospar/features/tasks/data/services/task_file_picker.dart';
import 'package:jospar/features/tasks/domain/entities/task_attachment_source.dart';
import 'package:jospar/features/tasks/domain/repositories/task_details_repository.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_creation_cubit.dart';
import 'package:jospar/features/tasks/presentation/cubit/task_details_cubit.dart';
import 'package:jospar/features/tasks/presentation/screens/task_creation_screen.dart';
import 'package:jospar/features/tasks/presentation/screens/task_details_screen.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_attachment_picker.dart';
import 'task_creation_test.dart' show CreationFakeRepository;
import 'task_test_app.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
XFile _photo() => XFile.fromData(
  _png,
  path: 'photo.png',
  name: 'photo.png',
  mimeType: 'image/png',
);
XFile _video() => XFile.fromData(
  Uint8List.fromList([0, 0, 0, 16, 102, 116, 121, 112, 105, 115, 111, 109]),
  name: 'video.mp4',
  path: 'video.mp4',
  mimeType: 'video/mp4',
);

class _Gallery extends ImagePickerPlatform {
  List<XFile> files = [_photo(), _video()];
  PlatformException? error;
  MediaOptions? options;
  int calls = 0;
  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    calls++;
    this.options = options;
    if (error != null) throw error!;
    return files;
  }
}

class _Files extends FilePickerPlatform {
  int calls = 0;
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
  }) async {
    calls++;
    return [];
  }
}

class _Oversized extends XFile {
  _Oversized() : super('big.mp4');
  @override
  String get name => 'big.mp4';
  @override
  Future<int> length() async => 1;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    yield Uint8List(TaskFilePicker.maxFileBytes + 1);
  }
}

class _Profile implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentUser() async =>
      const UserProfile(id: 'me', name: 'Member', email: 'member@example.test');
  @override
  Future<UserProfile> updateAvatar(String avatarUrl) => getCurrentUser();
}

class _Api implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool failComment = false;
  final task = <String, dynamic>{
    'id': 'task',
    'projectId': 'p',
    'title': 'Задача',
    'detail': {
      'description': 'Описание',
      'custom': {'keep': true},
    },
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    Object data = task;
    var status = 200;
    if (request.path.endsWith('/history') ||
        request.path == 'kanban-columns' ||
        request.path == 'epics') {
      data = [];
    } else if (request.method == 'PATCH') {
      task.addAll(Map<String, dynamic>.from(request.data as Map));
    } else if (request.method == 'POST' && request.path.endsWith('/comments')) {
      status = failComment ? 403 : 200;
      data = {
        'id': 'comment',
        'author': 'Member',
        'authorId': 'me',
        'text': (request.data as Map)['text'],
        'files': (request.data as Map)['files'],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<TaskDetailsCubit> _task(WidgetTester tester, _Api api) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final cubit = TaskDetailsCubit(
    TaskDetailsRepositoryImpl(Dio()..httpClientAdapter = api),
    _Profile(),
  );
  addTearDown(cubit.close);
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
  return cubit;
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _flush(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _Gallery gallery;
  late _Files files;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final oldGallery = ImagePickerPlatform.instance;
    final oldFiles = FilePickerPlatform.instance;
    ImagePickerPlatform.instance = gallery = _Gallery();
    FilePickerPlatform.instance = files = _Files();
    addTearDown(() {
      ImagePickerPlatform.instance = oldGallery;
      FilePickerPlatform.instance = oldFiles;
    });
  });

  test(
    'gallery encodes images and videos with metadata through the task file contract',
    () async {
      final picked = await TaskFilePicker.pick(
        source: TaskAttachmentSource.gallery,
        author: 'Member',
        authorId: 'me',
      );
      expect(picked.map((file) => file.type), ['image/png', 'video/mp4']);
      expect(picked.first.name, 'photo.png');
      expect(UriData.parse(picked.first.dataUrl!).contentAsBytes(), _png);
      expect(picked.first.uploadedByName, 'Member');
      expect(picked.first.raw['uploadedById'], 'me');
      expect(picked.map((file) => file.id).toSet(), hasLength(2));
      expect(gallery.options!.allowMultiple, isTrue);
      expect(gallery.options!.imageOptions.requestFullMetadata, isFalse);
      expect(files.calls, 0);
    },
  );
  test('gallery cancellation does not open the file picker', () async {
    gallery.files = [];
    expect(
      await TaskFilePicker.pick(source: TaskAttachmentSource.gallery),
      isEmpty,
    );
    expect(files.calls, 0);
  });
  test('gallery refuses empty media and streams larger than 10 MB', () async {
    gallery.files = [XFile.fromData(Uint8List(0), name: 'empty.png')];
    await expectLater(
      TaskFilePicker.pick(source: TaskAttachmentSource.gallery),
      throwsA(
        isA<TaskDetailsException>().having(
          (e) => e.message,
          'message',
          contains('пустой'),
        ),
      ),
    );
    gallery.files = [_Oversized()];
    await expectLater(
      TaskFilePicker.pick(source: TaskAttachmentSource.gallery),
      throwsA(
        isA<TaskDetailsException>().having(
          (e) => e.message,
          'message',
          contains('10 МБ'),
        ),
      ),
    );
  });
  test('gallery permission error does not silently switch sources', () async {
    gallery.error = PlatformException(code: 'photo_access_denied');
    await expectLater(
      TaskFilePicker.pick(source: TaskAttachmentSource.gallery),
      throwsA(
        isA<TaskDetailsException>().having(
          (e) => e.message,
          'message',
          contains('Нет доступа к галерее'),
        ),
      ),
    );
    expect(files.calls, 0);
  });

  testWidgets(
    'source choice supports cancellation and independent file and gallery paths',
    (tester) async {
      List<TaskFileModel>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await pickTaskAttachments(context),
                child: const Text('Добавить'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
      expect(gallery.calls + files.calls, 0);
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Файлы'));
      await tester.pumpAndSettle();
      expect(files.calls, 1);
      expect(gallery.calls, 0);
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Галерея'));
      await tester.pumpAndSettle();
      expect(result, hasLength(2));
      expect(gallery.calls, 1);
      expect(files.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery uploads task attachments through the existing API preserving detail',
    (tester) async {
      final api = _Api();
      final cubit = await _task(tester, api);
      final add = find.byKey(const Key('task-add-files'));
      await _scrollTo(tester, add);
      await tester.tap(add);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
      await tester.tap(find.text('Галерея'));
      await _flush(tester);
      expect(cubit.state.detail.files.map((file) => file.name), [
        'photo.png',
        'video.mp4',
      ]);
      expect(cubit.state.detail.raw['custom'], {'keep': true});
      expect(cubit.state.detail.description, 'Описание');
      expect(api.requests.where((r) => r.method == 'PATCH'), hasLength(1));
      expect(files.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discussion media stays a draft until send and survives a rejected comment',
    (tester) async {
      final api = _Api();
      final cubit = await _task(tester, api);
      final section = find.text('Обсуждение');
      await _scrollTo(tester, section);
      await tester.tap(section);
      await tester.pumpAndSettle();
      final add = find.byKey(const Key('discussion_attach'));
      await _scrollTo(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Галерея'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'photo.png'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'video.mp4'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
      final input = find.widgetWithText(TextField, 'Написать комментарий…');
      await tester.enterText(input, 'Материалы');
      final send = find.byTooltip('Отправить');
      await tester.ensureVisible(send);
      api.failComment = true;
      await tester.tap(send);
      await _flush(tester);
      expect(find.widgetWithText(InputChip, 'video.mp4'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, 'Материалы');
      api.failComment = false;
      await tester.tap(send);
      await _flush(tester);
      expect(
        cubit.state.detail.comments.single.files.map((file) => file.type),
        ['image/png', 'video/mp4'],
      );
      expect(find.byType(InputChip), findsNothing);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(files.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creation accepts gallery media into the draft without creating a task',
    (tester) async {
      final repo = CreationFakeRepository();
      final cubit = TaskCreationCubit(repo);
      addTearDown(cubit.close);
      await cubit.initialize(workspaceId: 'w');
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const TaskCreationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.byKey(const Key('create-task-files'));
      await _scrollTo(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Галерея'));
      await tester.pumpAndSettle();
      expect(cubit.state.draft.files.map((file) => file.name), [
        'photo.png',
        'video.mp4',
      ]);
      expect(repo.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:jospar/core/localization/app_translations.dart';
import 'package:jospar/core/widgets/user_avatar.dart';
import 'package:jospar/features/chat/presentation/widgets/conversation_menu.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/chat/presentation/screens/chat_screen.dart';
import 'package:jospar/features/chat/presentation/screens/conversation_screen.dart';
import 'package:jospar/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:jospar/core/network/dio_factory.dart';
import 'package:jospar/core/storage/auth_token_storage.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/chat/data/models/channel_info_model.dart';
import 'package:jospar/features/chat/data/models/chat_conversation_model.dart';
import 'package:jospar/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:jospar/features/chat/data/services/channel_photo_picker.dart';
import 'package:jospar/features/chat/domain/repositories/channel_image_repository.dart';
import 'package:jospar/features/chat/presentation/cubit/channel_info_cubit.dart';
import 'package:jospar/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:jospar/features/chat/presentation/widgets/channel_avatar.dart';
import 'package:jospar/features/chat/presentation/widgets/channel_info_sheet.dart';

class _Tokens extends AuthTokenStorage {
  _Tokens() : super(const FlutterSecureStorage());
  @override
  Future<String?> read() async => 'test-token';
}

class _Workspace extends WorkspaceSelectionStorage {
  const _Workspace() : super(const FlutterSecureStorage());
  @override
  Future<String?> read() async => 'workspace';
}

class _Api {
  _Api() {
    dio.interceptors.removeWhere(
      (interceptor) => interceptor is LogInterceptor,
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          requests.add(r);
          if (r.path == 'channels') {
            final snapshot = rows.values
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            if (readStarted != null && !readStarted!.isCompleted) {
              readStarted!.complete();
            }
            await readGate?.future;
            h.resolve(Response(requestOptions: r, data: snapshot));
          } else if (r.path.startsWith('workspaces/') &&
              r.path.endsWith('/members')) {
            h.resolve(Response(requestOptions: r, data: workspacePeople));
          } else if (r.method == 'PUT' && r.path.endsWith('/members')) {
            if (status != 200) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: r, statusCode: status),
                ),
              );
              return;
            }
            selectedMembers = List<String>.from(
              (r.data as Map)['memberIds'] as List,
            );
            h.resolve(Response(requestOptions: r, data: {'members': []}));
          } else if (r.path.endsWith('/members')) {
            final id = Uri.decodeComponent(r.path.split('/')[1]);
            h.resolve(
              Response(
                requestOptions: r,
                data: {
                  'members': [
                    {'id': 'member', 'name': 'Участник'},
                  ],
                  'imageUrl': rows[id]?['imageUrl'],
                  'canManageImage': canManageImage,
                  'canManage': canManage,
                },
              ),
            );
          } else if (r.method == 'PATCH') {
            if (!patchStarted.isCompleted) patchStarted.complete();
            await patchGate?.future;
            if (status != 200) {
              h.reject(
                DioException(
                  requestOptions: r,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: r, statusCode: status),
                ),
              );
              return;
            }
            final id = Uri.decodeComponent(r.path.split('/')[1]);
            rows[id]!['imageUrl'] = (r.data as Map)['imageUrl'];
            h.resolve(
              Response(requestOptions: r, data: rows[id], statusCode: 200),
            );
          } else {
            h.resolve(
              Response(
                requestOptions: r,
                data: r.path == 'users/me' ? {'id': 'me'} : [],
              ),
            );
          }
        },
      ),
    );
  }
  final dio = createDio(_Tokens(), workspaceStorage: const _Workspace());
  final rows = <String, Map<String, dynamic>>{
    'parent': {'id': 'parent', 'name': 'Главный', 'imageUrl': null},
    'child': {
      'id': 'child',
      'parentId': 'parent',
      'name': 'Подканал',
      'imageUrl': null,
    },
  };
  final workspacePeople = <Map<String, dynamic>>[
    {'id': 'member', 'name': 'Участник'},
    {'id': 'new', 'name': 'Новый коллега', 'email': 'new@example.test'},
  ];
  List<String>? selectedMembers;
  final requests = <RequestOptions>[];
  bool canManageImage = true, canManage = false;
  int status = 200;
  Completer<void>? readGate, readStarted, patchGate;
  final patchStarted = Completer<void>();
  ChatRepositoryImpl repository() =>
      ChatRepositoryImpl(dio, const _Workspace());
  Iterable<RequestOptions> get patches =>
      requests.where((r) => r.method == 'PATCH');
}

class _Picker implements ChannelPhotoPicker {
  String? value;
  ChannelPhotoError? error;
  int calls = 0;
  @override
  Future<String?> pick() async {
    calls++;
    if (error != null) throw ChannelPhotoException(error!);
    return value;
  }
}

class _Gallery extends ImagePickerPlatform {
  XFile? file;
  PlatformException? error;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    expect(source, ImageSource.gallery);
    expect(options.maxWidth, isNull);
    expect(options.maxHeight, isNull);
    if (error != null) throw error!;
    return file;
  }
}

class _Profile extends Cubit<ProfileState> implements ProfileCubit {
  _Profile() : super(const ProfileInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WorkspaceCubit extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _WorkspaceCubit()
    : super(
        const WorkspaceLoaded(
          workspaces: [WorkspaceModel(id: 'workspace', name: 'Работа')],
          selected: WorkspaceModel(id: 'workspace', name: 'Работа'),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _photo(int color) {
  final image = img.Image(width: 128, height: 128);
  img.fill(image, color: img.ColorRgb8(color, 100, 80));
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(image))}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppTranslations.load);
  TestWidgetsFlutterBinding.ensureInitialized();
  test('channel model round trips image and supports explicit removal', () {
    final channel = ChatConversationModel.fromChannelJson(const {
      'id': 'child',
      'name': 'Подканал',
      'parentId': 'parent',
      'imageUrl': 'data:image/jpeg;base64,AA==',
    });
    expect(ChatConversationModel.fromJson(channel.toJson()), channel);
    expect(channel.copyWith(unreadCount: 2).imageUrl, channel.imageUrl);
    expect(channel.copyWith(imageUrl: null).imageUrl, isNull);
    expect(channel.parentId, 'parent');
    final info = ChannelInfoModel.fromJson(const {
      'canManage': true,
      'canManageImage': 'true',
      'members': [],
    });
    expect(info.canManageImage, isFalse);
    expect(info.canManage, isTrue);
    expect(ChannelInfoModel.fromJson(info.toJson()), info);
  });
  test(
    'authenticated API sets, replaces and deletes each channel independently and survives a new repository',
    () async {
      final api = _Api();
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      final first = _photo(20), second = _photo(230);
      final chats = ChatCubit(repo);
      addTearDown(chats.close);
      await chats.load();
      expect(
        (chats.state as ChatLoaded).conversations
            .where((c) => c.isChannel)
            .length,
        2,
      );
      final info = await repo.channelInfo('parent');
      expect(info.canManageImage, isTrue);
      expect(info.canManage, isFalse);
      expect(info.members.single.name, 'Участник');
      await repo.setChannelImage('parent', first);
      await repo.setChannelImage('child', second);
      expect(
        (chats.state as ChatLoaded).conversations
            .firstWhere((c) => c.id == 'parent')
            .imageUrl,
        first,
      );
      expect(repo.channelImageSnapshot('child')!.imageUrl, second);
      await repo.setChannelImage('parent', second);
      await repo.setChannelImage('child', null);
      expect(repo.channelImageSnapshot('parent')!.imageUrl, second);
      expect(repo.channelImageSnapshot('child')!.imageUrl, isNull);
      expect(api.patches.last.data, {'imageUrl': null});
      for (final request in api.requests) {
        expect(request.uri.path, startsWith('/api/'));
        expect(request.uri.path, isNot(contains('/api/api/')));
        expect(request.headers['Authorization'], 'Bearer test-token');
      }
      final restarted = api.repository();
      addTearDown(restarted.dispose);
      final restored = await restarted.getConversations();
      expect(restored.firstWhere((c) => c.id == 'parent').imageUrl, second);
      expect(restored.firstWhere((c) => c.id == 'child').imageUrl, isNull);
    },
  );
  test(
    'a slow channel list cannot revert an image saved during that request',
    () async {
      final api = _Api()
        ..readGate = Completer<void>()
        ..readStarted = Completer<void>();
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      final pending = repo.getConversations();
      await api.readStarted!.future;
      final photo = _photo(30);
      await repo.setChannelImage('parent', photo);
      api.readGate!.complete();
      final result = await pending;
      expect(result.firstWhere((c) => c.id == 'parent').imageUrl, photo);
      expect(repo.channelImageSnapshot('parent')!.imageUrl, photo);
    },
  );
  test(
    'rejects oversized data URLs and unsupported outbound MIME types before sending',
    () async {
      final api = _Api();
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      for (final payload in [
        'data:image/jpeg;base64,${'A' * 100000}',
        'data:image/png;base64,AAAA',
        'https://example.com/photo.jpg',
      ]) {
        await expectLater(
          repo.setChannelImage('parent', payload),
          throwsA(isA<ChannelPhotoException>()),
        );
      }
      expect(api.patches, isEmpty);
    },
  );

  test(
    'failed writes keep photo and cache; repeated same URL still invalidates image cache',
    () async {
      final api = _Api();
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      final photo = _photo(40);
      await repo.setChannelImage('parent', photo);
      final revision = repo.channelImageSnapshot('parent')!.revision;
      await repo.setChannelImage('parent', photo);
      expect(
        repo.channelImageSnapshot('parent')!.revision,
        greaterThan(revision),
      );
      api.status = 500;
      await expectLater(
        repo.setChannelImage('parent', null),
        throwsA(isA<ChannelPhotoException>()),
      );
      expect(repo.channelImageSnapshot('parent')!.imageUrl, photo);
      expect(api.rows['parent']!['imageUrl'], photo);
    },
  );
  for (final allowed in [false, true]) {
    test(
      'photo rights are independent from member rights (photo=$allowed)',
      () async {
        final api = _Api()
          ..canManageImage = allowed
          ..canManage = !allowed;
        final repo = api.repository();
        final picker = _Picker()..value = _photo(90);
        final cubit = ChannelInfoCubit(repo, picker, 'parent');
        addTearDown(cubit.close);
        addTearDown(repo.dispose);
        addTearDown(api.dio.close);
        await cubit.load();
        await cubit.choosePhoto();
        expect(api.patches.length, allowed ? 1 : 0);
        expect(picker.calls, allowed ? 1 : 0);
      },
    );
  }
  test(
    'cancellation does not save, permission/decode failures preserve old image, server 403 revokes photo actions',
    () async {
      final api = _Api();
      final oldPhoto = _photo(100);
      api.rows['parent']!['imageUrl'] = oldPhoto;
      final repo = api.repository();
      final picker = _Picker();
      final cubit = ChannelInfoCubit(repo, picker, 'parent');
      addTearDown(cubit.close);
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      await cubit.load();
      await cubit.choosePhoto();
      expect(cubit.state.error, isNull);
      expect(api.patches, isEmpty);
      for (final error in [
        ChannelPhotoError.accessDenied,
        ChannelPhotoError.decode,
      ]) {
        picker.error = error;
        await cubit.choosePhoto();
        expect(cubit.state.error, error);
        expect(cubit.state.info!.imageUrl, oldPhoto);
        expect(cubit.state.saving, isFalse);
      }
      picker.error = null;
      picker.value = _photo(20);
      api.status = 403;
      await cubit.choosePhoto();
      expect(cubit.state.error, ChannelPhotoError.forbidden);
      expect(cubit.state.info!.canManageImage, isFalse);
      expect(cubit.state.info!.imageUrl, oldPhoto);
    },
  );
  test('a pending save prevents repeated picks and removals', () async {
    final api = _Api()..patchGate = Completer<void>();
    final repo = api.repository();
    final picker = _Picker()..value = _photo(30);
    final cubit = ChannelInfoCubit(repo, picker, 'parent');
    addTearDown(cubit.close);
    addTearDown(repo.dispose);
    addTearDown(api.dio.close);
    await cubit.load();
    final save = cubit.choosePhoto();
    await api.patchStarted.future;
    expect(cubit.state.saving, isTrue);
    expect(cubit.state.info!.imageUrl, isNull);
    await cubit.choosePhoto();
    await cubit.removePhoto();
    expect(picker.calls, 1);
    expect(api.patches.length, 1);
    api.patchGate!.complete();
    await save;
    expect(cubit.state.info!.imageUrl, picker.value);
    expect(cubit.state.saving, isFalse);
  });
  test(
    'PNG/JPEG are center-cropped without stretching and encoded as 128x128 JPEG within API limit',
    () {
      final source = img.Image(width: 384, height: 128);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(
        source,
        x1: 128,
        y1: 0,
        x2: 255,
        y2: 127,
        color: img.ColorRgb8(0, 255, 0),
      );
      for (final input in [img.encodePng(source), img.encodeJpg(source)]) {
        final output = encodeChannelPhoto(input);
        expect(output, startsWith('data:image/jpeg;base64,'));
        expect(output.length, lessThanOrEqualTo(100000));
        final decoded = img.decodeJpg(UriData.parse(output).contentAsBytes())!;
        expect(decoded.width, 128);
        expect(decoded.height, 128);
        expect(decoded.getPixel(0, 64).g, greaterThan(200));
        expect(decoded.getPixel(127, 64).g, greaterThan(200));
      }
    },
  );
  test('gallery JPEG orientation is applied before cropping', () {
    final image = img.Image(width: 128, height: 128);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    img.fillRect(
      image,
      x1: 0,
      y1: 64,
      x2: 127,
      y2: 127,
      color: img.ColorRgb8(0, 0, 255),
    );
    image.exif.imageIfd.orientation = 6;
    final output = encodeChannelPhoto(img.encodeJpg(image));
    final decoded = img.decodeJpg(UriData.parse(output).contentAsBytes())!;
    expect(decoded.getPixel(10, 64).b, greaterThan(200));
    expect(decoded.getPixel(117, 64).r, greaterThan(200));
  });

  test('WebP input is accepted and transcoded', () {
    final output = encodeChannelPhoto(
      File('test/fixtures/channel_photo.webp').readAsBytesSync(),
    );
    expect(img.decodeJpg(UriData.parse(output).contentAsBytes())!.width, 128);
  });
  test('rejects oversized input, unsupported formats and damaged images', () {
    expect(
      () =>
          encodeChannelPhoto(Uint8List(GalleryChannelPhotoPicker.maxBytes + 1)),
      throwsA(
        isA<ChannelPhotoException>().having(
          (e) => e.code,
          'code',
          ChannelPhotoError.tooLarge,
        ),
      ),
    );
    expect(
      () => encodeChannelPhoto(Uint8List.fromList([71, 73, 70, 56, 57, 97])),
      throwsA(
        isA<ChannelPhotoException>().having(
          (e) => e.code,
          'code',
          ChannelPhotoError.format,
        ),
      ),
    );
    expect(
      () => encodeChannelPhoto(Uint8List.fromList([255, 216, 255, 0])),
      throwsA(
        isA<ChannelPhotoException>().having(
          (e) => e.code,
          'code',
          ChannelPhotoError.decode,
        ),
      ),
    );
  });
  test(
    'gallery cancellation and denied access are handled by the platform adapter',
    () async {
      final original = ImagePickerPlatform.instance;
      final gallery = _Gallery();
      ImagePickerPlatform.instance = gallery;
      addTearDown(() => ImagePickerPlatform.instance = original);
      final picker = GalleryChannelPhotoPicker();
      expect(await picker.pick(), isNull);
      gallery.error = PlatformException(code: 'photo_access_denied');
      await expectLater(
        picker.pick(),
        throwsA(
          isA<ChannelPhotoException>().having(
            (e) => e.code,
            'code',
            ChannelPhotoError.accessDenied,
          ),
        ),
      );
      gallery.error = null;
      gallery.file = XFile.fromData(
        img.encodePng(img.Image(width: 32, height: 64)),
        name: 'photo.png',
      );
      expect(await picker.pick(), startsWith('data:image/jpeg;base64,'));
      gallery.file = XFile.fromData(
        Uint8List(GalleryChannelPhotoPicker.maxBytes + 1),
        name: 'large.png',
      );
      await expectLater(
        picker.pick(),
        throwsA(
          isA<ChannelPhotoException>().having(
            (e) => e.code,
            'code',
            ChannelPhotoError.tooLarge,
          ),
        ),
      );
    },
  );
  testWidgets(
    'all mounted channel avatars update together and revert to hash on removal',
    (tester) async {
      final api = _Api();
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChannelAvatar(channelId: 'parent', size: 27, repository: repo),
                ChannelAvatar(channelId: 'parent', size: 32, repository: repo),
                ChannelAvatar(channelId: 'child', size: 27, repository: repo),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      await tester.runAsync(() => repo.setChannelImage('parent', _photo(30)));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.fit, BoxFit.cover);
        expect(image.alignment, Alignment.center);
      }
      expect(find.byType(ClipOval), findsNWidgets(3));
      await tester.runAsync(() => repo.setChannelImage('parent', null));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'list channel information saves photo and updates its row without changing the child',
    (tester) async {
      final api = _Api();
      final repo = api.repository();
      final chats = ChatCubit(repo);
      final picker = _Picker()..value = _photo(20);
      sl.registerSingleton<ChannelPhotoPicker>(picker);
      addTearDown(() => sl.unregister<ChannelPhotoPicker>());
      addTearDown(chats.close);
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      await tester.runAsync(chats.load);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: chats),
              BlocProvider<ProfileCubit>(create: (_) => _Profile()),
              BlocProvider<WorkspaceCubit>(create: (_) => _WorkspaceCubit()),
            ],
            child: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('channel-expand-parent')));
      await tester.pumpAndSettle();
      final avatars = tester
          .widgetList<ChannelAvatar>(find.byType(ChannelAvatar))
          .toList();
      expect(avatars.length, 2);
      expect(avatars.map((a) => a.size).toSet().length, 1);
      await tester.tap(find.byTooltip('Действия: Главный'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Информация о канале'));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelInfoSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('channel-photo-choose')));
      await tester.pumpAndSettle();
      expect(api.rows['parent']!['imageUrl'], picker.value);
      expect(api.rows['child']!['imageUrl'], isNull);
      await tester.tap(find.byTooltip('Закрыть').last);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        (chats.state as ChatLoaded).conversations
            .firstWhere((c) => c.id == 'parent')
            .imageUrl,
        picker.value,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'open conversation header receives photo updates and opens channel information',
    (tester) async {
      final api = _Api();
      final repo = api.repository();
      const channel = ChatConversationModel(
        id: 'parent',
        threadId: 'parent',
        title: 'Главный',
        isChannel: true,
      );
      final cubit = ConversationCubit(repo, channel);
      addTearDown(cubit.close);
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const ConversationScreen(conversation: channel),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChannelAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.runAsync(() => repo.setChannelImage('parent', _photo(200)));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byKey(const Key('conversation-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Информация о канале'));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelInfoSheet), findsOneWidget);
      expect(find.text('Заменить фото'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'member candidates load from the selected workspace with avatar URLs',
    () async {
      final api = _Api();
      api.workspacePeople.last['avatarUrl'] = _photo(180);
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      final candidates = await repo.workspaceChannelCandidates();
      expect(candidates.map((e) => e.userId), ['member', 'new']);
      expect(candidates.last.avatarUrl, api.workspacePeople.last['avatarUrl']);
      expect(api.requests.single.uri.path, '/api/workspaces/workspace/members');
      expect(api.requests.single.headers['Authorization'], 'Bearer test-token');
    },
  );

  testWidgets(
    'members dialog includes workspace users absent from chats and preserves selected users through search and failed save',
    (tester) async {
      final api = _Api()
        ..canManage = true
        ..canManageImage = false;
      final photo = _photo(180);
      api.workspacePeople.last['avatarUrl'] = photo;
      final repo = api.repository();
      addTearDown(repo.dispose);
      addTearDown(api.dio.close);
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationMenuButton(
              conversation: const ChatConversationModel(
                id: 'parent',
                threadId: 'parent',
                title: 'Главный',
                isChannel: true,
              ),
              repository: repo,
              chats: const [],
              onChanged: () async {
                refreshed++;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Действия: Главный'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Участники'));
      await tester.pumpAndSettle();
      expect(find.text('Новый коллега'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('channel-member-member')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widgetList<UserAvatar>(find.byType(UserAvatar))
            .firstWhere((a) => a.userId == 'new')
            .avatarUrl,
        photo,
      );
      await tester.tap(find.byKey(const ValueKey('channel-member-new')));
      await tester.enterText(
        find.byKey(const Key('channel-members-search')),
        'Участник',
      );
      await tester.pumpAndSettle();
      expect(find.text('Новый коллега'), findsNothing);
      api.status = 500;
      await tester.tap(find.byKey(const Key('channel-members-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('channel-members-search')), findsOneWidget);
      expect(find.textContaining('Не удалось'), findsOneWidget);
      expect(refreshed, 0);
      api.status = 200;
      await tester.tap(find.byKey(const Key('channel-members-save')));
      await tester.pumpAndSettle();
      expect(api.selectedMembers, containsAll(['member', 'new']));
      expect(refreshed, 1);
      expect(find.byKey(const Key('channel-members-search')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('photo management rights do not enable member editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final api = _Api()
      ..canManage = false
      ..canManageImage = true;
    final repo = api.repository();
    addTearDown(repo.dispose);
    addTearDown(api.dio.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: ConversationMenuButton(
            conversation: const ChatConversationModel(
              id: 'parent',
              threadId: 'parent',
              title: 'Главный',
              isChannel: true,
            ),
            repository: repo,
            chats: const [],
            onChanged: () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Действия: Главный'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Участники'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('channel-members-sheet')), findsOneWidget);
    expect(find.byKey(const Key('channel-members-save')), findsNothing);
    for (final checkbox in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(checkbox.onChanged, isNull);
    }
    expect(find.text('Новый коллега'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byKey(const Key('channel-members-close'))).dy,
      lessThanOrEqualTo(328),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final kk in [false, true]) {
    for (final allowed in [false, true]) {
      testWidgets(
        'info shows localized photo actions only with photo rights (kk=$kk, allowed=$allowed)',
        (tester) async {
          final api = _Api()
            ..canManageImage = allowed
            ..canManage = !allowed;
          final repo = api.repository();
          final picker = _Picker()..value = _photo(70);
          final cubit = ChannelInfoCubit(repo, picker, 'parent');
          addTearDown(cubit.close);
          addTearDown(repo.dispose);
          addTearDown(api.dio.close);
          await tester.runAsync(cubit.load);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(kk ? 'kk' : 'ru'),
              supportedLocales: const [Locale('ru'), Locale('kk')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: kk ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: BlocProvider.value(
                  value: cubit,
                  child: ChannelInfoSheet(
                    channel: const ChatConversationModel(
                      id: 'parent',
                      threadId: 'parent',
                      title: 'Главный',
                      isChannel: true,
                    ),
                    repository: repo,
                  ),
                ),
              ),
            ),
          );
          expect(
            find.byKey(const Key('channel-photo-choose')),
            allowed ? findsOneWidget : findsNothing,
          );
          if (allowed) {
            expect(
              find.text(kk ? 'Фото таңдау' : 'Выбрать фото'),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('channel-photo-choose')));
            await tester.pumpAndSettle();
            expect(
              find.text(kk ? 'Фотоны ауыстыру' : 'Заменить фото'),
              findsOneWidget,
            );
            expect(
              find.text(kk ? 'Фотоны жою' : 'Удалить фото'),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('channel-photo-remove')));
            await tester.pumpAndSettle();
            expect(
              find.text(kk ? 'Фото таңдау' : 'Выбрать фото'),
              findsOneWidget,
            );
            expect(api.rows['parent']!['imageUrl'], isNull);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

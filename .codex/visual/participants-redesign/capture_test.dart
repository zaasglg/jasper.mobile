import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/collaboration/data/project_participants_repository.dart';
import 'package:jospar/features/collaboration/presentation/project_participants_screen.dart';

class PreviewApi implements HttpClientAdapter {
  bool error = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    Object? body;
    var status = 200;
    if (r.path == 'users/me') {
      body = {'id': 'one'};
    } else if (r.path.endsWith('/members/me')) {
      body = {'role': 'SUPER_ADMIN'};
    } else if (r.path.contains('/invite-link')) {
      status = error ? 503 : 200;
      body = {
        'url': 'https://josparbee.kz/join/illustrative-preview-token',
        'role': 'EXECUTOR',
      };
    } else if (r.path.endsWith('/members')) {
      final people = [
        {
          'id': 'one',
          'name': 'Алина Касымова',
          'email': 'alina@example.test',
          'role': 'SUPER_ADMIN',
          'access': 'workspace',
        },
        {
          'id': 'two',
          'name': 'Данияр Мурзин',
          'email': 'dmurzin@example.test',
          'role': 'EXECUTOR',
          'access': 'workspace',
        },
        {
          'id': 'three',
          'name': 'Ерлан Бекенов',
          'email': 'erlan@example.test',
          'role': 'EXECUTOR',
          'access': 'project',
        },
      ];
      body = r.path.startsWith('workspaces/')
          ? people
          : {'members': people, 'pendingInvites': []};
    } else {
      body = {
        'id': 'preview',
        'name': 'Мобильное приложение',
        'workspaceId': 'workspace',
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('render participants in representative visual states', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final bytes = ByteData.sublistView(
      File('.codex/visual/project-board/Manrope.ttf').readAsBytesSync(),
    );
    for (final family in [
      'Manrope',
      'Manrope_regular',
      'Manrope_medium',
      'Manrope_semiBold',
      'Manrope_bold',
      'Manrope_500',
      'Manrope_600',
      'Manrope_700',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final picture = await tester.runAsync(() => boundary.toImage());
      final data = await tester.runAsync(
        () => picture!.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(
        () => File(
          '.codex/visual/participants-redesign/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List()),
      );
    }

    for (final item in [
      ('mobile', const Size(440, 956), 1.0, false),
      ('small-large-text', const Size(320, 640), 2.0, false),
      ('link-error', const Size(440, 956), 1.0, false),
    ]) {
      tester.view.physicalSize = item.$2;
      final api = PreviewApi()..error = item.$1 == 'link-error';
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(item.$3)),
              child: child!,
            ),
            home: ProjectParticipantsScreen(
              id: 'preview',
              repository: ProjectParticipantsRepository(
                Dio()..httpClientAdapter = api,
              ),
            ),
          ),
        ),
      );
      await capture(item.$1);
      if (item.$1 == 'mobile') {
        await tester.tap(find.byKey(const Key('participants_add')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'invalid');
        await tester.tap(find.text('Пригласить по email'));
        await capture('invite-invalid');
        await tester.enterText(find.byType(TextField), 'new@example.test');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await capture('invite-keyboard');
        tester.view.viewInsets = const FakeViewPadding();
        await tester.tap(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
      }
    }
  });
}

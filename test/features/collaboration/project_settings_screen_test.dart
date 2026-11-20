import 'dart:io';
import 'package:flutter/services.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/di/service_locator.dart';
import 'package:jospar/features/collaboration/domain/entities/managed_space.dart';
import 'package:jospar/features/collaboration/domain/entities/space_member.dart';
import 'package:jospar/features/collaboration/domain/entities/space_kind.dart';
import 'package:jospar/features/collaboration/domain/collaboration_repository.dart';
import 'package:jospar/features/collaboration/presentation/space_management_screen.dart';

class _Repository implements CollaborationRepository {
  Map<String, dynamic>? saved;
  @override
  Future<ManagedSpace> getSpace(SpaceKind kind, String id) async =>
      const ManagedSpace(id: 'p', name: 'Мой проект', code: 'PR');
  @override
  Future<List<SpaceMember>> members(SpaceKind kind, String id) async => [];
  @override
  Future<void> updateSpace(
    SpaceKind kind,
    String id,
    Map<String, dynamic> changes,
  ) async {
    saved = changes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const previewFont = String.fromEnvironment('SETTINGS_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isEmpty) return;
    final bytes = ByteData.sublistView(await File(previewFont).readAsBytes());
    for (final family in [
      'Ahem',
      'Roboto',
      'Manrope',
      'Manrope_regular',
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
  });

  testWidgets(
    'project settings omit dates and save other fields at narrow width',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.reset();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository();
      sl.registerSingleton<CollaborationRepository>(repository);
      addTearDown(() => sl.unregister<CollaborationRepository>());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const SpaceManagementScreen(kind: SpaceKind.project, id: 'p'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Начало проекта'), findsNothing);
      expect(find.text('Окончание проекта'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('project_settings_name')),
        'Новый проект',
      );
      final save = find.byKey(const Key('project_settings_save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.saved?['name'], 'Новый проект');
      expect(repository.saved?.containsKey('start'), false);
      expect(repository.saved?.containsKey('end'), false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('project settings visual layout', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sl.registerSingleton<CollaborationRepository>(_Repository());
    addTearDown(() => sl.unregister<CollaborationRepository>());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SpaceManagementScreen(kind: SpaceKind.project, id: 'p'),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/project_settings.png'),
    );
  }, skip: previewFont.isEmpty);
}

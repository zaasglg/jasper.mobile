import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/features/tasks/presentation/widgets/task_details_skeleton.dart';

void main() {
  testWidgets(
    'turning on reduced motion stops skeleton and indicator animations',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      Widget screen(bool reduceMotion) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const Scaffold(body: TaskDetailsSkeleton()),
        ),
      );
      await tester.pumpWidget(screen(false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNotNull,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Загрузка задачи…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small screen supports large text and accessible navigation without motion',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.8),
              accessibleNavigation: true,
            ),
            child: const Scaffold(body: TaskDetailsSkeleton()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

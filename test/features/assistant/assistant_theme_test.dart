import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/assistant/presentation/widgets/assistant_web_layout.dart';

void main() {
  testWidgets('dark assistant keeps typed text and header readable', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AssistantWebHeader(
                  workspaceName: 'Команда',
                  onStopVoice: () {},
                  onVoiceHelp: () {},
                ),
                AssistantWebComposer(
                  input: input,
                  focus: focus,
                  enabled: true,
                  sending: false,
                  listening: false,
                  picking: false,
                  attachments: const [],
                  onSend: () {},
                  onVoice: () {},
                  onAttach: () {},
                  onRemove: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('assistant-input')), 'Привет');
    await tester.pumpAndSettle();
    const colors = AppPalette(true);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.color, colors.ink);
    expect(field.cursorColor, colors.accent);
    expect(input.text, 'Привет');
    expect(
      tester.widget<Text>(find.text('Новый чат')).style!.color,
      colors.ink,
    );
    final send = tester.widget<FilledButton>(
      find.byKey(const Key('assistant-send')),
    );
    expect(send.onPressed, isNotNull);
    expect(send.style!.foregroundColor!.resolve({}), colors.onAccent);
    await tester.tap(find.byTooltip('Действия помощника'));
    await tester.pumpAndSettle();
    expect(find.text('Остановить озвучивание'), findsOneWidget);
    expect(find.text('Голосовой вызов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

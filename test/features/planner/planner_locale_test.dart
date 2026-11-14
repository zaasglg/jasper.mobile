import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['ru', 'kk', 'en']) {
    testWidgets('time picker follows system language $language', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localesTestValue = [Locale(language)];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      late String title;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: [
            for (final code in kMaterialSupportedLanguages) Locale(code),
          ],
          home: Builder(
            builder: (context) {
              title = MaterialLocalizations.of(context).timePickerDialHelpText;
              return Scaffold(
                body: TextButton(
                  onPressed: () => showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  ),
                  child: Text(Localizations.localeOf(context).languageCode),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(language));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      if (language != 'en') expect(find.text('Select time'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

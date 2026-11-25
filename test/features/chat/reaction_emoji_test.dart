import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/chat/presentation/widgets/reaction_emoji.dart';

void main() {
  testWidgets('bundled reaction artwork loads and preserves fixed dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final emoji in ReactionEmoji.assets.keys)
                ReactionEmoji(emoji, size: 32),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(24));
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(image.image, isA<AssetImage>());
      expect(image.width, 32);
      expect(image.height, 32);
      expect(image.fit, BoxFit.contain);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'heart variation uses the same artwork and custom emoji stays available',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ReactionEmoji('❤️'),
                ReactionEmoji('❤'),
                ReactionEmoji('🐝'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, 2);
      expect(images.first.image, images.last.image);
      expect(find.text('🐝'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

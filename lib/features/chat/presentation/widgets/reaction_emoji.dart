import 'package:flutter/widgets.dart';

/// Bundled Fluent Emoji artwork. The wire value remains the original Unicode.
class ReactionEmoji extends StatelessWidget {
  const ReactionEmoji(this.emoji, {super.key, this.size = 28});
  final String emoji;
  final double size;
  static const assets = <String, String>{
    '👍': 'thumbs_up',
    '❤': 'red_heart',
    '😂': 'face_with_tears_of_joy',
    '😮': 'face_with_open_mouth',
    '😢': 'crying_face',
    '🙏': 'folded_hands',
    '🔥': 'fire',
    '✅': 'check_mark_button',
    '🎉': 'party_popper',
    '😍': 'smiling_face_with_heart-eyes',
    '👏': 'clapping_hands',
    '😁': 'beaming_face_with_smiling_eyes',
    '🤔': 'thinking_face',
    '💯': 'hundred_points',
    '🤝': 'handshake',
    '👀': 'eyes',
    '🙌': 'raising_hands',
    '💜': 'purple_heart',
    '💪': 'flexed_biceps',
    '🥰': 'smiling_face_with_hearts',
    '🤗': 'hugging_face',
    '😎': 'smiling_face_with_sunglasses',
    '🤩': 'star-struck',
    '👌': 'ok_hand',
  };
  @override
  Widget build(BuildContext context) {
    final name = assets[emoji.replaceAll('\uFE0F', '')];
    Widget fallback() => Center(
      child: Text(
        emoji,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: size * .85),
      ),
    );
    return Semantics(
      label: emoji,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: name == null
            ? fallback()
            : Image.asset(
                'assets/emoji/reactions/$name.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

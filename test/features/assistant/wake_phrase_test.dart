import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/assistant/domain/utils/wake_phrase.dart';

void main() {
  test('recognizes English and Russian wake phrases with punctuation', () {
    for (final phrase in [
      'Ok, Jospar',
      'OK JOSPAR',
      'Okay Jospar',
      'Окей, Жоспар',
      'Ок Джоспар',
      'Окей Жос пар',
      'Ok Josparbee',
    ]) {
      expect(commandAfterWakePhrase(phrase), '', reason: phrase);
    }
    expect(
      commandAfterWakePhrase('Окей, Жоспар какие задачи на сегодня?'),
      'какие задачи на сегодня',
    );
  });
  test('does not activate on mentions or unrelated words', () {
    for (final phrase in [
      'Jospar',
      'Я сказал Ok Jospar',
      'Ok Jasper',
      'Ok Josparov',
      'Покажи задачи',
    ]) {
      expect(commandAfterWakePhrase(phrase), isNull, reason: phrase);
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/utils/html_text.dart';

void main() {
  test('removes markup and decodes named and numeric entities', () {
    expect(
      htmlToPlainText(
        '<p>Школа <strong>Болашақ</strong> &amp; 7&nbsp;500 м&#178;.</p>',
      ),
      'Школа Болашақ & 7 500 м².',
    );
  });
  test('keeps paragraphs, breaks and list entries readable', () {
    final text = htmlToPlainText(
      '<p>Первый<br>Второй</p><p>Третий</p><ul><li>Один</li><li><b>Два</b></li></ul>',
    );
    expect(text, contains('Первый\nВторой'));
    expect(text, contains('Третий'));
    expect(text, contains('• Один'));
    expect(text, contains('• Два'));
  });
  test(
    'ignores invisible content and handles empty and plain descriptions',
    () {
      expect(htmlToPlainText('<p><br></p>&nbsp;'), isEmpty);
      expect(
        htmlToPlainText(
          '<style>p{color:red}</style><p>Текст</p><script>alert(1)</script>',
        ),
        'Текст',
      );
      expect(
        htmlToPlainText('Значение 2 < 3\nВторая строка'),
        'Значение 2 < 3\nВторая строка',
      );
    },
  );
}

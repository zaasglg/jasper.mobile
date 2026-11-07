import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/dashboard/presentation/widgets/yandex_task_map_html.dart';

void main() {
  test(
    'Yandex task points reject invalid coordinates and preserve zero values',
    () {
      final points = validYandexTaskPoints([
        ('zero', 'Ноль', 0, 0),
        ('a', 'Школа', 43.2, 76.8),
        ('bad', 'Ошибка', 91, 0),
        ('infinite', 'Ошибка', double.infinity, 0),
        ('nan', 'Ошибка', 0, double.nan),
        ('', 'Нет ID', 43, 76),
      ]);
      expect(points.map((p) => p.$1), ['zero', 'a']);
    },
  );
  test(
    'Yandex map document escapes task data and loads only the Yandex API',
    () {
      final html = buildYandexTaskMapHtml('test key', [
        ('id', '</script><img src=x onerror=alert(1)>', 43.2, 76.8),
      ]);
      expect(html, contains('api-maps.yandex.ru/2.1/'));
      expect(html, contains('lang=ru_RU'));
      expect(html, contains(r'\u003c/script\u003e'));
      expect(html, isNot(contains('</script><img')));
      expect(html, isNot(contains('openstreetmap')));
      expect(html, contains("send({type:'select',id:point.id})"));
      expect(html, contains('window.josparUpdateTasks'));
      expect(html, contains('checkZoomRange:true'));
    },
  );
}

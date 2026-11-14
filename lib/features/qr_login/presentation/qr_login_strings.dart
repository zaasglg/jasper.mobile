import 'package:flutter/widgets.dart';

class QrLoginStrings {
  const QrLoginStrings._(this.kk);
  factory QrLoginStrings.of(BuildContext context) => QrLoginStrings._(
    Localizations.localeOf(context).languageCode.toLowerCase() == 'kk',
  );
  final bool kk;

  String get title => kk ? 'QR арқылы кіру' : 'Вход по QR';
  String get scanHint => kk
      ? 'Компьютер экранындағы QR-кодты жақтауға орналастырыңыз'
      : 'Поместите QR-код с экрана компьютера в рамку';
  String get allowTitle => kk
      ? 'Orbita-ға кіруге рұқсат беру керек пе?'
      : 'Разрешить вход в Orbita?';
  String get account => kk ? 'Мобильді аккаунт' : 'Мобильный аккаунт';
  String get device => kk ? 'Браузер және ОЖ' : 'Браузер и ОС';
  String get ip => 'IP';
  String get expires => kk ? 'Қалған уақыт' : 'Осталось';
  String get allow => kk ? 'Кіруге рұқсат беру' : 'Разрешить вход';
  String get cancel => kk ? 'Бас тарту' : 'Отмена';
  String get approved => kk ? 'Кіруге рұқсат берілді' : 'Вход разрешён';
  String get expired => kk
      ? 'QR-кодтың мерзімі аяқталды. Оны компьютерде жаңартыңыз.'
      : 'QR-код истёк. Обновите его на компьютере.';
  String get cameraDenied => kk
      ? 'Камераға рұқсат жоқ. Оны жүйе баптауларында қосыңыз.'
      : 'Нет доступа к камере. Разрешите его в настройках системы.';
  String get cameraUnavailable => kk
      ? 'Бұл құрылғыда камера қолжетімсіз.'
      : 'Камера недоступна на этом устройстве.';
  String get retry => kk ? 'Қайталау' : 'Повторить';

  String error(String russian) {
    if (!kk) return russian;
    return switch (russian) {
      'Некорректный QR-код.' => 'QR-код жарамсыз.',
      'Сервер вернул некорректный ответ.' => 'Сервер жарамсыз жауап қайтарды.',
      'Сессия недействительна. Войдите снова и отсканируйте новый QR.' =>
        'Сессия жарамсыз. Қайта кіріп, жаңа QR-кодты сканерлеңіз.',
      'QR-код уже изменён или использован. Обновите его на компьютере.' =>
        'QR-код өзгертілген немесе қолданылған. Оны компьютерде жаңартыңыз.',
      'QR-код истёк. Обновите его на компьютере.' =>
        'QR-кодтың мерзімі аяқталды. Оны компьютерде жаңартыңыз.',
      'Слишком много запросов. Повторите через минуту.' =>
        'Сұраулар тым көп. Бір минуттан кейін қайталаңыз.',
      _ => 'Серверге қосылу мүмкін болмады. Интернетті тексеріп, қайталаңыз.',
    };
  }
}

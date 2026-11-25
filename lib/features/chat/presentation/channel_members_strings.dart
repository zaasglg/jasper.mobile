import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/widgets.dart';

class ChannelMembersStrings {
  const ChannelMembersStrings(this.kk);
  factory ChannelMembersStrings.of(BuildContext context) =>
      ChannelMembersStrings(
        Localizations.localeOf(context).languageCode == 'kk',
      );
  final bool kk;
  String get title =>
      AppTranslations.translate('Участники канала', kk ? 'kk' : 'ru');
  String get workspaceMembers =>
      AppTranslations.translate('Участники воркспейса', kk ? 'kk' : 'ru');
  String get search =>
      AppTranslations.translate('Поиск по имени или почте', kk ? 'kk' : 'ru');
  String get save => AppTranslations.translate('Сохранить', kk ? 'kk' : 'ru');
  String get cancel => AppTranslations.translate('Отмена', kk ? 'kk' : 'ru');
  String get close => AppTranslations.translate('Закрыть', kk ? 'kk' : 'ru');
  String get readOnly => AppTranslations.translate(
    'У вас нет права изменять состав канала.',
    kk ? 'kk' : 'ru',
  );
  String get empty =>
      AppTranslations.translate('Участники не найдены', kk ? 'kk' : 'ru');
  String get saveError => AppTranslations.translate(
    'Не удалось сохранить участников. Попробуйте ещё раз.',
    kk ? 'kk' : 'ru',
  );
}

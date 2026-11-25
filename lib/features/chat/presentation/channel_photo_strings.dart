import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/widgets.dart';
import '../domain/repositories/channel_image_repository.dart';

class ChannelPhotoStrings {
  const ChannelPhotoStrings(this.kk);
  factory ChannelPhotoStrings.of(BuildContext context) =>
      ChannelPhotoStrings(Localizations.localeOf(context).languageCode == 'kk');
  final bool kk;
  String get info =>
      AppTranslations.translate('Информация о канале', kk ? 'kk' : 'ru');
  String get choose =>
      AppTranslations.translate('Выбрать фото', kk ? 'kk' : 'ru');
  String get replace =>
      AppTranslations.translate('Заменить фото', kk ? 'kk' : 'ru');
  String get remove =>
      AppTranslations.translate('Удалить фото', kk ? 'kk' : 'ru');
  String get saving =>
      AppTranslations.translate('Сохранение фотографии…', kk ? 'kk' : 'ru');
  String get members =>
      AppTranslations.translate('Участники', kk ? 'kk' : 'ru');
  String get retry => AppTranslations.translate('Повторить', kk ? 'kk' : 'ru');
  String get close => AppTranslations.translate('Закрыть', kk ? 'kk' : 'ru');
  String error(ChannelPhotoError error) => switch (error) {
    ChannelPhotoError.accessDenied => AppTranslations.translate(
      'Нет доступа к галерее. Разрешите его в настройках устройства.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.format => AppTranslations.translate(
      'Выберите изображение PNG, JPEG или WebP.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.tooLarge => AppTranslations.translate(
      'Выберите фото размером до 5 МБ.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.decode => AppTranslations.translate(
      'Не удалось открыть фото. Выберите другое изображение.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.save => AppTranslations.translate(
      'Не удалось сохранить фото. Попробуйте ещё раз.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.load => AppTranslations.translate(
      'Не удалось загрузить информацию о канале. Попробуйте ещё раз.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.forbidden => AppTranslations.translate(
      'У вас нет права изменять фотографию канала.',
      kk ? 'kk' : 'ru',
    ),
    ChannelPhotoError.invalidResponse => AppTranslations.translate(
      'Сервер вернул некорректный ответ. Попробуйте ещё раз.',
      kk ? 'kk' : 'ru',
    ),
  };
}

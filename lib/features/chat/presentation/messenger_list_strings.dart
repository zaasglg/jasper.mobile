import 'package:jospar/core/localization/app_translations.dart';
import '../data/models/chat_message_preview_model.dart';
import '../data/models/chat_message_model.dart';
import 'package:flutter/widgets.dart';

class MessengerListStrings {
  const MessengerListStrings(this.kk);
  factory MessengerListStrings.of(BuildContext context) => MessengerListStrings(
    Localizations.localeOf(context).languageCode == 'kk',
  );
  final bool kk;
  String folder(String name) => switch (name) {
    'channels' => AppTranslations.translate('Каналы', kk ? 'kk' : 'ru'),
    'people' => AppTranslations.translate('Личные', kk ? 'kk' : 'ru'),
    _ => AppTranslations.translate('Все чаты', kk ? 'kk' : 'ru'),
  };
  String preview(ChatMessagePreviewModel message, {required bool isChannel}) {
    final body = switch (message.kind) {
      ChatMessageKind.audio => AppTranslations.translate(
        'Голосовое сообщение',
        kk ? 'kk' : 'ru',
      ),
      ChatMessageKind.videoMessage => AppTranslations.translate(
        'Видеосообщение',
        kk ? 'kk' : 'ru',
      ),
      ChatMessageKind.call => AppTranslations.translate(
        'Звонок',
        kk ? 'kk' : 'ru',
      ),
      ChatMessageKind.poll => AppTranslations.translate(
        'Опрос',
        kk ? 'kk' : 'ru',
      ),
      _ =>
        message.text.isEmpty || message.text.startsWith('data:')
            ? (AppTranslations.translate('Сообщение', kk ? 'kk' : 'ru'))
            : message.text,
    };
    final author = message.isOwn
        ? (AppTranslations.translate('Вы', kk ? 'kk' : 'ru'))
        : isChannel
        ? message.authorName
        : null;
    return author == null || author.isEmpty ? body : '$author: $body';
  }

  String get deleteChat =>
      AppTranslations.translate('Удалить чат', kk ? 'kk' : 'ru');
  String get deleteChatTitle =>
      AppTranslations.translate('Удалить чат?', kk ? 'kk' : 'ru');
  String get deleteConfirm =>
      AppTranslations.translate('Удалить', kk ? 'kk' : 'ru');
  String get deleteChatDescription => AppTranslations.translate(
    'Чат и история переписки будут скрыты только у вас. У собеседника они сохранятся. При новом сообщении чат снова появится в списке.',
    kk ? 'kk' : 'ru',
  );

  String get search => AppTranslations.translate('Поиск', kk ? 'kk' : 'ru');
  String get newChat =>
      AppTranslations.translate('Новый чат', kk ? 'kk' : 'ru');
  String get addChannel =>
      AppTranslations.translate('Добавить канал', kk ? 'kk' : 'ru');
  String get addPerson =>
      AppTranslations.translate('Добавить коллег', kk ? 'kk' : 'ru');
  String get tools =>
      AppTranslations.translate('Действия мессенджера', kk ? 'kk' : 'ru');
  String get mentions =>
      AppTranslations.translate('Упоминания и реакции', kk ? 'kk' : 'ru');
  String get saved =>
      AppTranslations.translate('Сохранённое', kk ? 'kk' : 'ru');
  String get storage => AppTranslations.translate('Кладовка', kk ? 'kk' : 'ru');
  String get channel => AppTranslations.translate('Канал', kk ? 'kk' : 'ru');
  String get subchannel =>
      AppTranslations.translate('Подканал', kk ? 'kk' : 'ru');
  String get online => AppTranslations.translate('в сети', kk ? 'kk' : 'ru');
  String get personalMessages =>
      AppTranslations.translate('Личные сообщения', kk ? 'kk' : 'ru');
  String get personal =>
      AppTranslations.translate('Личная переписка', kk ? 'kk' : 'ru');
}

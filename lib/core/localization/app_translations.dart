import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Uses the website's normalized FNV-1a keys and unchanged dictionaries.
abstract final class AppTranslations {
  static Map<String, String> _ru = {}, _kk = {}, _mobile = {};
  static final _aliases = <String, String>{};
  static Future<void>? _loading;
  static String normalize(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
  static String key(String text) {
    var hash = 0x811c9dc5;
    for (final unit in normalize(text).codeUnits) {
      hash = ((hash ^ unit) * 0x1000193) & 0xffffffff;
    }
    return 'm_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final data = await Future.wait([
      rootBundle.loadString('assets/l10n/web_ru.json'),
      rootBundle.loadString('assets/l10n/web_kk.json'),
      rootBundle.loadString('assets/l10n/mobile_kk.json'),
    ]);
    _ru = Map<String, String>.from(jsonDecode(data[0]) as Map);
    _kk = Map<String, String>.from(jsonDecode(data[1]) as Map);
    _mobile = Map<String, String>.from(jsonDecode(data[2]) as Map);
    for (final entry in _ru.entries) {
      final value = _kk[entry.key];
      if (value == null) continue;
      _aliases.putIfAbsent(normalize(entry.value), () => value);
      final names = <String, String>{};
      final canonical = entry.value.replaceAllMapped(
        RegExp(r'\{(\w+)\}'),
        (m) => '{${names.putIfAbsent(m[1]!, () => 'p${names.length}')}}',
      );
      var translated = value;
      names.forEach((name, placeholder) {
        translated = translated.replaceAll('{$name}', '{$placeholder}');
      });
      _aliases.putIfAbsent(normalize(canonical), () => translated);
    }
  }

  static String translate(
    String source,
    String locale, [
    Map<String, Object?> values = const {},
  ]) {
    final text = normalize(source);
    var output = source;
    if (locale == 'kk' && text.isNotEmpty) {
      final translated = _kk[key(text)] ?? _aliases[text] ?? _mobile[text];
      if (translated != null) {
        final leading = RegExp(r'^\s*').firstMatch(source)![0]!;
        final trailing = RegExp(r'\s*$').firstMatch(source)![0]!;
        output = '$leading$translated$trailing';
      }
    }
    // Explicit templates preserve all user-supplied values verbatim. Never
    // guess translations by matching the contents of user titles/messages.
    return output.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => values.containsKey(m[1]) ? '${values[m[1]] ?? ''}' : m[0]!,
    );
  }
}

/// Interface copy only; task titles, names and messages stay in their language.
String tr(
  BuildContext context,
  String source, [
  Map<String, Object?> values = const {},
]) => AppTranslations.translate(
  source,
  Localizations.maybeLocaleOf(context)?.languageCode ?? 'ru',
  values,
);
String? trn(BuildContext context, String? source) =>
    source == null ? null : tr(context, source);

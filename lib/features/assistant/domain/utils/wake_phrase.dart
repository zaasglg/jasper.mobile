final _wakePhrase = RegExp(
  r'^(?:ok|okay|okey|ок|окей|о\s*кей)\s+(?:jospar(?:bee)?|жоспар(?:би)?|джоспар(?:би)?|джос пар|жос пар)(?:\s|$)',
  caseSensitive: false,
);
String? commandAfterWakePhrase(String words) {
  final normalized = words
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-яёііңғүұқөһә0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final match = _wakePhrase.firstMatch(normalized);
  if (match == null) return null;
  return normalized.substring(match.end).trim();
}

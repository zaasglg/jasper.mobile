String plannerIconTitle(String title) {
  final value = title.trim();
  return value.length > 500 ? value.substring(0, 500) : value;
}

abstract interface class TaskIconRepository {
  Future<Map<String, String>> getIcons(List<String> titles);
}

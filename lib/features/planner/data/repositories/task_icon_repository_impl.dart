import 'package:dio/dio.dart';
import '../../domain/repositories/task_icon_repository.dart';

class TaskIconRepositoryImpl implements TaskIconRepository {
  TaskIconRepositoryImpl(this._dio);
  final Dio _dio;
  final _cache = <String, ({String icon, DateTime expires})>{};

  @override
  Future<Map<String, String>> getIcons(List<String> titles) async {
    final keys =
        titles
            .map(plannerIconTitle)
            .where((title) => title.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final now = DateTime.now();
    final result = <String, String>{};
    final missing = <String>[];
    for (final key in keys) {
      final cached = _cache[key];
      if (cached != null && cached.expires.isAfter(now)) {
        result[key] = cached.icon;
      } else {
        missing.add(key);
      }
    }
    for (var start = 0; start < missing.length; start += 30) {
      final batch = missing.sublist(
        start,
        (start + 30).clamp(0, missing.length),
      );
      final response = await _dio.post<dynamic>(
        'ai/assistant/task-icons',
        data: {'titles': batch},
      );
      final data = response.data;
      if (data is! Map || data['icons'] is! List) {
        throw const FormatException('Некорректный ответ сервиса иконок.');
      }
      final icons = data['icons'] as List;
      for (var i = 0; i < batch.length; i++) {
        final raw = i < icons.length ? icons[i] : null;
        final icon = raw is String && raw.trim().isNotEmpty
            ? raw.trim().toLowerCase()
            : 'task';
        result[batch[i]] = icon;
        _cache.remove(batch[i]);
        _cache[batch[i]] = (
          icon: icon,
          expires: DateTime.now().add(const Duration(hours: 24)),
        );
      }
      while (_cache.length > 512) {
        _cache.remove(_cache.keys.first);
      }
    }
    return result;
  }
}

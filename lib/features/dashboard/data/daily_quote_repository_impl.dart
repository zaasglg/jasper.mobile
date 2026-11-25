import 'package:dio/dio.dart';
import '../domain/daily_quote_repository.dart';
import '../domain/entities/daily_quote.dart';

class DailyQuoteRepositoryImpl implements DailyQuoteRepository {
  const DailyQuoteRepositoryImpl(this.dio);
  final Dio dio;
  @override
  Future<DailyQuote> load(String workspaceId) async {
    final response = await dio.get<dynamic>(
      'ai/daily-motivation',
      queryParameters: {'workspaceId': workspaceId},
      options: Options(headers: {'X-Workspace-Id': workspaceId}),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Некорректная цитата дня');
    }
    return DailyQuote.fromJson(data);
  }
}

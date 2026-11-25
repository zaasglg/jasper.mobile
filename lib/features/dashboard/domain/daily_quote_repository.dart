import 'entities/daily_quote.dart';

abstract interface class DailyQuoteRepository {
  Future<DailyQuote> load(String workspaceId);
}

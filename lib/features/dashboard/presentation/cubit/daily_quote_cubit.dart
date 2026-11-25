import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/daily_quote_repository.dart';
import '../../domain/entities/daily_quote.dart';

enum DailyQuoteStatus { loading, ready, failure }

class DailyQuoteState extends Equatable {
  const DailyQuoteState({this.status = DailyQuoteStatus.loading, this.quote});
  final DailyQuoteStatus status;
  final DailyQuote? quote;
  @override
  List<Object?> get props => [status, quote];
}

class DailyQuoteCubit extends Cubit<DailyQuoteState> {
  DailyQuoteCubit(this.repository, this.workspaceId)
    : super(const DailyQuoteState());
  final DailyQuoteRepository repository;
  final String workspaceId;
  Timer? _timer;
  bool _loading = false;
  bool _active = true;
  void setActive(bool active) {
    _active = active;
    if (!active) {
      _timer?.cancel();
    } else {
      load();
    }
  }

  Future<void> load() async {
    if (isClosed || _loading || !_active || workspaceId.isEmpty) return;
    _timer?.cancel();
    _loading = true;
    try {
      final quote = await repository.load(workspaceId);
      if (!isClosed) {
        emit(DailyQuoteState(status: DailyQuoteStatus.ready, quote: quote));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          DailyQuoteState(status: DailyQuoteStatus.failure, quote: state.quote),
        );
      }
    } finally {
      _loading = false;
      if (!isClosed && _active) {
        _timer = Timer(
          state.quote?.refreshing == true
              ? const Duration(milliseconds: 1500)
              : const Duration(minutes: 5),
          load,
        );
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/google_calendar_models.dart';
import '../../domain/repositories/google_calendar_repository.dart';
import '../../domain/repositories/planner_repository.dart';
import '../../domain/utils/planner_dates.dart';

class GoogleCalendarState extends Equatable {
  const GoogleCalendarState({
    this.connection = const GoogleCalendarStatus(),
    this.events = const [],
    this.loading = false,
    this.error,
    this.showEvents = true,
    this.includeHolidays = true,
  });
  final GoogleCalendarStatus connection;
  final List<GoogleCalendarEvent> events;
  final bool loading, showEvents, includeHolidays;
  final String? error;
  GoogleCalendarState copyWith({
    GoogleCalendarStatus? connection,
    List<GoogleCalendarEvent>? events,
    bool? loading,
    bool? showEvents,
    bool? includeHolidays,
    String? error,
  }) => GoogleCalendarState(
    connection: connection ?? this.connection,
    events: events ?? this.events,
    loading: loading ?? this.loading,
    showEvents: showEvents ?? this.showEvents,
    includeHolidays: includeHolidays ?? this.includeHolidays,
    error: error,
  );
  @override
  List<Object?> get props => [
    connection,
    events,
    loading,
    error,
    showEvents,
    includeHolidays,
  ];
}

class GoogleCalendarCubit extends Cubit<GoogleCalendarState> {
  GoogleCalendarCubit(this.repository) : super(const GoogleCalendarState());
  final GoogleCalendarRepository repository;
  DateTime? _start, _end;
  int _revision = 0;
  Timer? _authorizationPoll;
  bool _disconnecting = false;

  Future<void> range(DateTime selected, {bool force = false}) async {
    final first = DateTime(selected.year, selected.month, 1);
    // Include the leading/trailing days of the month's grid.
    final start = DateTime(first.year, first.month, 1 - first.weekday + 1);
    final end = start.add(const Duration(days: 42));
    if (!force && _start == start) return;
    _start = start;
    _end = end;
    await refresh(clearEvents: true);
  }

  Future<void> refresh({bool clearEvents = false}) async {
    final start = _start, end = _end;
    if (start == null || end == null || isClosed || _disconnecting) return;
    final revision = ++_revision;
    emit(state.copyWith(loading: true, events: clearEvents ? [] : null));
    try {
      final connection = await repository.status();
      if (isClosed || revision != _revision) return;
      if (!connection.connected) {
        emit(
          state.copyWith(connection: connection, events: [], loading: false),
        );
        return;
      }
      emit(state.copyWith(connection: connection));
      final events = await repository.events(
        plannerInstant(start, 0, 0),
        plannerInstant(end, 0, 0),
        includeHolidays: state.includeHolidays,
      );
      if (isClosed || revision != _revision) return;
      emit(
        state.copyWith(connection: connection, events: events, loading: false),
      );
      _authorizationPoll?.cancel();
    } catch (e) {
      if (isClosed || revision != _revision) return;
      emit(
        state.copyWith(
          loading: false,
          error: e is PlannerException
              ? e.message
              : 'Не удалось загрузить Google Календарь.',
        ),
      );
    }
  }

  void showEvents(bool value) => emit(state.copyWith(showEvents: value));
  Future<void> holidays(bool value) async {
    emit(state.copyWith(includeHolidays: value));
    await refresh(clearEvents: true);
  }

  /// OAuth completes at the existing web callback. Check the same server account
  /// on return, without passing the Jospar bearer token to the external browser.
  void awaitAuthorization() {
    _authorizationPoll?.cancel();
    var attempts = 0;
    _authorizationPoll = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (++attempts >= 40 || isClosed) timer.cancel();
      if (!isClosed && !state.loading) unawaited(refresh());
    });
  }

  Future<void> disconnect() async {
    if (_disconnecting) return;
    _disconnecting = true;
    _authorizationPoll?.cancel();
    ++_revision;
    emit(state.copyWith(loading: true));
    try {
      await repository.disconnect();
      if (!isClosed) {
        emit(
          state.copyWith(
            connection: const GoogleCalendarStatus(),
            events: [],
            loading: false,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            loading: false,
            error: e is PlannerException
                ? e.message
                : 'Не удалось отключить Google.',
          ),
        );
      }
    } finally {
      _disconnecting = false;
    }
  }

  @override
  Future<void> close() {
    _authorizationPoll?.cancel();
    ++_revision;
    return super.close();
  }
}

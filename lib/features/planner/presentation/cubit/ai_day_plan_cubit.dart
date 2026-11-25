import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../assistant/domain/entities/assistant_request.dart';
import '../../data/planner_changes.dart';
import '../../domain/entities/ai_day_plan_entry.dart';
import '../../domain/repositories/ai_day_plan_repository.dart';
import '../../domain/repositories/planner_repository.dart';
import '../../domain/utils/planner_dates.dart';

enum AiDayPlanStatus { loading, ready, saving, complete, failure }

class AiDayPlanState extends Equatable {
  const AiDayPlanState({
    this.status = AiDayPlanStatus.loading,
    this.entries = const [],
    this.error,
  });
  final AiDayPlanStatus status;
  final List<AiDayPlanEntry> entries;
  final String? error;
  int get pendingCount => entries.where((e) => e.selected && !e.saved).length;
  @override
  List<Object?> get props => [status, entries, error];
}

class AiDayPlanCubit extends Cubit<AiDayPlanState> {
  AiDayPlanCubit({
    required this.repository,
    required this.planner,
    required this.workspaceId,
    required this.day,
    required this.scopeIsCurrent,
    DateTime Function()? now,
  }) : _now = now ?? plannerNow,
       super(const AiDayPlanState());
  final AiDayPlanRepository repository;
  final PlannerRepository planner;
  final String workspaceId;
  final DateTime day;
  final Future<bool> Function() scopeIsCurrent;
  final DateTime Function() _now;
  AssistantRequest? _request;
  bool _busy = false;

  Future<void> _check() async {
    if (isClosed || !await scopeIsCurrent()) {
      throw const AiDayPlanException(
        'Аккаунт или рабочее пространство изменились. Откройте план заново.',
      );
    }
    if (!samePlannerDay(day, _now())) {
      throw const AiDayPlanException(
        'Наступил новый день. Откройте план заново.',
      );
    }
  }

  Future<void> generate() async {
    if (_busy || state.entries.any((e) => e.saved)) return;
    _busy = true;
    final request = _request = AssistantRequest();
    emit(const AiDayPlanState());
    try {
      await _check();
      final entries = await repository.suggest(
        workspaceId: workspaceId,
        day: day,
        request: request,
      );
      await _check();
      if (!isClosed && !request.isCancelled) {
        emit(AiDayPlanState(status: AiDayPlanStatus.ready, entries: entries));
      }
    } catch (e) {
      if (!isClosed && !request.isCancelled) {
        emit(
          AiDayPlanState(status: AiDayPlanStatus.failure, error: _message(e)),
        );
      }
    } finally {
      _busy = false;
    }
  }

  void edit(AiDayPlanEntry entry) {
    if (_busy || isClosed || state.status != AiDayPlanStatus.ready) return;
    emit(
      AiDayPlanState(
        status: AiDayPlanStatus.ready,
        entries: [
          for (final current in state.entries)
            if (current.taskId == entry.taskId && !current.saved)
              entry
            else
              current,
        ],
      ),
    );
  }

  Future<void> confirm() async {
    if (_busy ||
        state.status != AiDayPlanStatus.ready ||
        state.pendingCount == 0) {
      return;
    }
    _busy = true;
    var entries = [...state.entries];
    var changed = false;
    emit(AiDayPlanState(status: AiDayPlanStatus.saving, entries: entries));
    try {
      await _check();
      final existing = await planner.load();
      await _check();
      // Linked planner entries are unique per task. Never move an existing plan,
      // even if it was added on another device after the AI suggestion.
      final plannedIds = existing
          .map((e) => e.taskId)
          .whereType<String>()
          .toSet();
      entries = [
        for (final e in entries)
          if (e.selected && !e.saved && plannedIds.contains(e.taskId))
            e.copyWith(saved: true)
          else
            e,
      ];
      final timed = entries
          .where((e) => e.selected && !e.saved && e.startMinute != null)
          .toList();
      for (final e in entries.where((e) => e.selected && !e.saved)) {
        if (e.durationMinutes < 15 ||
            e.durationMinutes > 180 ||
            (e.startMinute != null &&
                (e.startMinute! < 0 ||
                    e.startMinute! + e.durationMinutes > 1440))) {
          throw const AiDayPlanException(
            'Проверьте время и длительность задач.',
          );
        }
      }
      bool overlap(int a, int length, int b, int otherLength) =>
          a < b + otherLength && b < a + length;
      for (var i = 0; i < timed.length; i++) {
        final e = timed[i];
        final localStart = DateTime(
          day.year,
          day.month,
          day.day,
          0,
          e.startMinute!,
        );
        if (localStart.isBefore(_now())) {
          throw const AiDayPlanException(
            'Выберите время позже текущего или оставьте задачу без времени.',
          );
        }
        for (final other in timed.skip(i + 1)) {
          if (overlap(
            e.startMinute!,
            e.durationMinutes,
            other.startMinute!,
            other.durationMinutes,
          )) {
            throw const AiDayPlanException(
              'Время предложенных задач пересекается. Измените план.',
            );
          }
        }
        for (final other in existing.where(
          (item) => !item.archived && item.scheduledAt != null,
        )) {
          final start = other.scheduledAt!.toLocal();
          if (localStart.isBefore(
                start.add(Duration(minutes: other.durationMinutes)),
              ) &&
              start.isBefore(
                localStart.add(Duration(minutes: e.durationMinutes)),
              )) {
            throw const AiDayPlanException(
              'Выбранное время занято в ежедневнике. Измените план.',
            );
          }
        }
      }
      for (var index = 0; index < entries.length; index++) {
        final e = entries[index];
        if (!e.selected || e.saved) continue;
        await _check();
        await planner.addTask(
          projectId: e.projectId,
          taskId: e.taskId,
          scheduledAt: e.startMinute == null
              ? null
              : DateTime(
                  day.year,
                  day.month,
                  day.day,
                  0,
                  e.startMinute!,
                ).toUtc(),
          plannedDate: e.startMinute == null ? day : null,
          durationMinutes: e.durationMinutes,
        );
        changed = true;
        entries = [
          for (var i = 0; i < entries.length; i++)
            if (i == index) e.copyWith(saved: true) else entries[i],
        ];
        if (!isClosed) {
          emit(
            AiDayPlanState(
              status: AiDayPlanStatus.saving,
              entries: [...entries],
            ),
          );
        }
      }
      if (!isClosed) {
        emit(
          AiDayPlanState(status: AiDayPlanStatus.complete, entries: entries),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          AiDayPlanState(
            status: AiDayPlanStatus.ready,
            entries: entries,
            error: _message(e),
          ),
        );
      }
    } finally {
      _busy = false;
      if (changed) notifyPlannerChanges();
    }
  }

  String _message(Object e) => switch (e) {
    AiDayPlanException() => e.message,
    PlannerException() => e.message,
    _ =>
      'Не удалось сохранить план. Уже добавленные задачи сохранены; повторная попытка проверит ежедневник.',
  };

  @override
  Future<void> close() {
    _request?.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../projects/domain/entities/project_task_model.dart';
import '../../../tasks/domain/entities/task_resource_model.dart';
import '../../../tasks/domain/repositories/task_details_repository.dart';
import '../../domain/entities/resource_pair_total.dart';

enum ColumnResourceStatus { loading, success, failure }

class ColumnResourceState extends Equatable {
  const ColumnResourceState({
    this.status = ColumnResourceStatus.loading,
    this.pairs = const [],
    this.taskCount = 0,
    this.message,
  });
  final ColumnResourceStatus status;
  final List<ResourcePairTotal> pairs;
  final int taskCount;
  final String? message;
  @override
  List<Object?> get props => [status, pairs, taskCount, message];
}

class ColumnResourceCubit extends Cubit<ColumnResourceState> {
  ColumnResourceCubit({
    required List<ProjectTaskModel> tasks,
    required this.repository,
    required this.isScopeActive,
    this.planFallback = 'План',
    this.factFallback = 'Факт',
    Stream<Object?>? scopeChanges,
  }) : tasks = List.unmodifiable(tasks),
       _session = authSession.generation,
       super(const ColumnResourceState()) {
    authSession.addListener(_checkScope);
    _scopeSubscription = scopeChanges?.listen((_) => _checkScope());
  }
  final List<ProjectTaskModel> tasks;
  final TaskResourceReadRepository? repository;
  final bool Function() isScopeActive;
  final String planFallback;
  final String factFallback;
  final int _session;
  int _revision = 0;
  StreamSubscription<Object?>? _scopeSubscription;
  bool get _active =>
      !isClosed && _session == authSession.generation && isScopeActive();

  void _checkScope() {
    if (_active || isClosed) return;
    _revision++;
    emit(
      const ColumnResourceState(
        status: ColumnResourceStatus.failure,
        message: 'Сводка больше недоступна. Откройте колонку заново.',
      ),
    );
  }

  Future<void> load() async {
    if (!_active) {
      _checkScope();
      return;
    }
    final revision = ++_revision;
    bool current() => _active && revision == _revision;
    emit(const ColumnResourceState());
    final values = List<List<TaskResourceModel>?>.filled(tasks.length, null);
    var next = 0;
    var failed = false;
    Future<void> worker() async {
      while (!failed && current() && next < tasks.length) {
        final index = next++;
        final task = tasks[index];
        try {
          final inline = task.resources;
          final resources =
              inline != null && inline.length >= task.resourceCount
              ? inline
              : await repository!.getResources(task.id);
          if (!current()) return;
          if (resources.any(
            (r) => !r.planValue.isFinite || !r.factValue.isFinite,
          )) {
            throw const FormatException('Invalid resource values');
          }
          values[index] = resources;
        } catch (_) {
          failed = true;
          rethrow;
        }
      }
    }

    try {
      // At most four per-task GETs; never publish intermediate totals.
      await Future.wait(
        List.generate(tasks.length.clamp(0, 4), (_) => worker()),
      );
      if (!current()) {
        _checkScope();
        return;
      }
      if (values.any((value) => value == null)) {
        throw const FormatException('Incomplete resources');
      }
      final pairs = summarizeTaskResourcePairs(
        values.cast<List<TaskResourceModel>>(),
        planFallback: planFallback,
        factFallback: factFallback,
      );
      emit(
        ColumnResourceState(
          status: ColumnResourceStatus.success,
          pairs: pairs,
          taskCount: tasks.length,
        ),
      );
    } catch (error) {
      if (!current()) {
        _checkScope();
        return;
      }
      emit(
        ColumnResourceState(
          status: ColumnResourceStatus.failure,
          message:
              error is TaskDetailsException &&
                  error.message == 'Недостаточно прав для просмотра ресурсов'
              ? error.message
              : 'Не удалось загрузить ресурсы. Повторите попытку.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _revision++;
    authSession.removeListener(_checkScope);
    await _scopeSubscription?.cancel();
    return super.close();
  }
}

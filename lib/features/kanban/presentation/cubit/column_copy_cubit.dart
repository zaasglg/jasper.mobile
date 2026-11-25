import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../tasks/domain/entities/kanban_column_model.dart';
import '../../domain/entities/column_copy_result.dart';
import 'kanban_cubit.dart';

class ColumnCopyCubit extends Cubit<ColumnCopyResult> {
  ColumnCopyCubit(this.board, this.column, this.isScreenActive)
    : super(const ColumnCopyResult(ColumnCopyStatus.idle));

  final KanbanCubit board;
  final KanbanColumnModel column;
  final bool Function() isScreenActive;

  bool get isActive => !isClosed && isScreenActive();

  Future<void> submit(String name) async {
    if (!isActive ||
        state.status == ColumnCopyStatus.submitting ||
        {
          ColumnCopyStatus.success,
          ColumnCopyStatus.uncertain,
          ColumnCopyStatus.forbidden,
          ColumnCopyStatus.stale,
        }.contains(state.status)) {
      return;
    }
    emit(const ColumnCopyResult(ColumnCopyStatus.submitting));
    final result = await board.copyColumn(
      column,
      name,
      isActive: () => isActive,
    );
    if (isActive) emit(result);
  }

  Future<void> refresh() async {
    if (!isActive || state.status == ColumnCopyStatus.submitting) return;
    final previous = state;
    emit(const ColumnCopyResult(ColumnCopyStatus.submitting));
    await board.load(
      board.state.projectId,
      refresh: true,
      isActive: () => isActive,
    );
    if (isActive) emit(previous);
  }
}

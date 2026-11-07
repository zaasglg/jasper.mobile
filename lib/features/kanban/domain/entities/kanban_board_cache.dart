import 'kanban_board_data.dart';
import '../../../../core/auth/auth_session.dart';

class KanbanBoardCache {
  int _generation = authSession.generation;
  final Map<String, KanbanBoardData> _boards = <String, KanbanBoardData>{};

  void clear() => _boards.clear();

  void _syncSession() {
    if (_generation == authSession.generation) return;
    clear();
    _generation = authSession.generation;
  }

  KanbanBoardData? read(String projectId) {
    _syncSession();
    return _boards[projectId];
  }

  void write(String projectId, KanbanBoardData board) {
    _syncSession();
    _boards[projectId] = board;
  }
}

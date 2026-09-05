import 'kanban_board_data.dart';

class KanbanBoardCache {
  final Map<String, KanbanBoardData> _boards = <String, KanbanBoardData>{};

  KanbanBoardData? read(String projectId) => _boards[projectId];

  void write(String projectId, KanbanBoardData board) {
    _boards[projectId] = board;
  }
}

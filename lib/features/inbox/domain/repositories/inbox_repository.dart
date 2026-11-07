import '../../data/models/inbox_task_model.dart';

abstract interface class InboxRepository {
  Future<List<InboxTaskModel>> getInbox({bool archived = true, int sort = 1});

  Future<void> createInbox({required String title});

  Future<void> completeInboxTask({required String id});
}

abstract interface class InboxActionsRepository {
  Future<void> updateTask(String id, Map<String, dynamic> changes);
  Future<void> deleteTask(String id);
  Future<void> copyTask(InboxTaskModel task);
  Future<void> moveTask(String id, String projectId);
}

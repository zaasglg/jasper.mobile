import '../../data/models/inbox_task_model.dart';

abstract interface class InboxRepository {
  Future<List<InboxTaskModel>> getInbox({bool archived = true, int sort = 1});

  Future<void> createInbox({required String title});
}

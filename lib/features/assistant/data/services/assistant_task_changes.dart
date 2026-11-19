import '../../../tasks/data/services/task_changes.dart';

/// Compatibility names for existing AI action callers and task consumers.
final assistantTaskChanges = taskChanges;
void notifyAssistantTaskChanges() => notifyTaskChanges();

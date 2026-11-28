import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/workspaces/workspace_cubit_test.dart' as workspaces;
import '../test/features/workspaces/workspace_multi_select_test.dart'
    as workspace_ui;
import '../test/features/projects/project_move_test.dart' as projects;
import '../test/features/tasks/my_tasks_cubit_test.dart' as tasks;
import '../test/features/tasks/my_tasks_widget_test.dart' as tasks_ui;
import '../test/features/collaboration/archive_cubit_test.dart' as archive;
import '../test/features/collaboration/collaboration_test.dart'
    as collaboration;
import '../test/features/qr_login/qr_sessions_cubit_test.dart' as sessions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Workspace persistence', workspaces.main);
  group('Workspace screens', workspace_ui.main);
  group('Project moves', projects.main);
  group('Task filters', tasks.main);
  group('Task screens', tasks_ui.main);
  group('Archive races', archive.main);
  group('Archive screens', collaboration.main);
  group('Session lifecycle', sessions.main);
}

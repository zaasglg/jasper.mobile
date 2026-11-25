import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/repositories/inbox_repository.dart';
import '../../domain/entities/inbox_task_model.dart';

final _completingWidgetTasks = <String>{};

@pragma('vm:entry-point')
Future<void> inboxWidgetAction(Uri? uri) async {
  if (uri?.host != 'complete') return;
  final id = uri?.queryParameters['id'];
  if (id == null || id.isEmpty) return;
  if (!_completingWidgetTasks.add(id)) return;
  try {
    if (!sl.isRegistered<InboxRepository>()) await initServiceLocator();
    await HomeWidget.setAppGroupId(InboxHomeWidgetService.appGroupId);
    final repository = sl<InboxRepository>();
    await repository.completeInboxTask(id: id);
    await InboxHomeWidgetService.sync(
      await repository.getInbox(archived: false),
    );
  } catch (error) {
    debugPrint('Inbox widget completion failed: $error');
  } finally {
    _completingWidgetTasks.remove(id);
  }
}

/// Keeps the native Android/iOS home-screen widget in sync with Inbox.
abstract final class InboxHomeWidgetService {
  static const String appGroupId = 'group.com.jospar.app';
  static const String androidProvider = 'com.jospar.app.InboxWidgetProvider';
  static const String iOSWidgetKind = 'InboxHomeWidget';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.registerInteractivityCallback(inboxWidgetAction);
    } on PlatformException catch (error) {
      debugPrint('Inbox widget initialization failed: $error');
    }
  }

  static Future<void> sync(List<InboxTaskModel> tasks) async {
    final pending = tasks.where((task) => !task.completed).toList();
    try {
      await HomeWidget.saveWidgetData<int>('inbox_count', pending.length);
      for (var index = 0; index < 3; index++) {
        final title = index < pending.length ? pending[index].title : '';
        await HomeWidget.saveWidgetData<String>(
          'inbox_task_id_${index + 1}',
          index < pending.length ? pending[index].id : '',
        );
        await HomeWidget.saveWidgetData<String>(
          'inbox_task_${index + 1}',
          title,
        );
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iOSWidgetKind,
      );
    } on PlatformException catch (error) {
      // Widget APIs are unavailable in unit tests and on unsupported platforms.
      debugPrint('Inbox widget update failed: $error');
    } catch (error) {
      debugPrint('Inbox widget update failed: $error');
    }
  }
}

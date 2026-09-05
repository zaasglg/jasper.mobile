import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../models/inbox_task_model.dart';

/// Keeps the native Android/iOS home-screen widget in sync with Inbox.
abstract final class InboxHomeWidgetService {
  static const String appGroupId = 'group.com.example.jospar';
  static const String androidProvider =
      'com.example.jospar.InboxWidgetProvider';
  static const String iOSWidgetKind = 'InboxHomeWidget';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
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

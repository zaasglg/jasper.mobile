import 'package:flutter/foundation.dart';

/// Refreshes existing planner views after an explicit scheduling action.
final plannerChanges = ValueNotifier<int>(0);

void notifyPlannerChanges() => plannerChanges.value++;

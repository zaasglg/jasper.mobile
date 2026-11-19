import 'package:flutter/foundation.dart';

/// Invalidates task consumers after a successful task mutation.
final taskChanges = ValueNotifier<int>(0);
void notifyTaskChanges() => taskChanges.value++;

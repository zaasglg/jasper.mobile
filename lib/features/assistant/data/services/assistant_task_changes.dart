import 'package:flutter/foundation.dart';

/// Invalidates visible task consumers after an AI mutation.
final assistantTaskChanges = ValueNotifier<int>(0);
void notifyAssistantTaskChanges() => assistantTaskChanges.value++;

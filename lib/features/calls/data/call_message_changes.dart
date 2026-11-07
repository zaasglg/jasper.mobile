import 'package:flutter/foundation.dart';

final callMessageChanges = ValueNotifier<int>(0);
void notifyCallMessageChanges() => callMessageChanges.value++;

import 'package:flutter/foundation.dart';

/// A successful send/read changes previews and unread counts in the chat list.
final chatListChanges = ValueNotifier<int>(0);
void notifyChatListChanges() => chatListChanges.value++;

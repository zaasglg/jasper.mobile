import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/repositories/chat_repository.dart';
import 'models/chat_interaction_models.dart';

/// Same timing as the web: heartbeat <= 2s, idle stop 4s, server TTL 6s.
class ThreadTypingController extends ChangeNotifier {
  ThreadTypingController(
    this.repository,
    this.threadId, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final ChatInteractionRepository repository;
  final String threadId;
  List<ChatTypingUser> users = const [];
  String? _workspace;
  bool _active = false, _own = false, _fetching = false, _disposed = false;
  int _epoch = 0;
  DateTime? _lastSent;
  Timer? _poll, _idle, _expiry;
  bool _starting = false;
  Future<void> _updates = Future.value();
  void setActive(bool active) {
    if (_active == active || _disposed) return;
    _active = active;
    final epoch = ++_epoch;
    _poll?.cancel();
    if (!active) {
      stop();
      users = const [];
      _expiry?.cancel();
      notifyListeners();
      return;
    }
    unawaited(_start(epoch));
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_workspace == null) {
        unawaited(_start(epoch));
      } else {
        unawaited(_refresh(epoch));
      }
    });
  }

  Future<void> _start(int epoch) async {
    if (_starting) return;
    _starting = true;
    try {
      final workspace = await repository.interactionWorkspaceId();
      if (!_active || _disposed || epoch != _epoch) return;
      _workspace = workspace;
      unawaited(_refresh(epoch));
    } catch (_) {
      /* Optional presence must not prevent messaging. */
    } finally {
      _starting = false;
    }
  }

  Future<void> _refresh(int epoch) async {
    if (_fetching || !_active || _workspace == null) return;
    _fetching = true;
    try {
      final next = await repository.typing(threadId, _workspace!);
      if (!_disposed && _active && epoch == _epoch) {
        users = next;
        _expiry?.cancel();
        _expiry = Timer(const Duration(seconds: 6), () {
          if (!_disposed && epoch == _epoch) {
            users = const [];
            notifyListeners();
          }
        });
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        users = const [];
        notifyListeners();
      }
    } finally {
      _fetching = false;
    }
  }

  void _send(bool value) {
    final workspace = _workspace;
    if (workspace == null) return;
    _updates = _updates
        .then((_) => repository.updateTyping(threadId, workspace, value))
        .catchError((Object _) {});
  }

  void textChanged(String text) {
    if (!_active || _disposed || text.trim().isEmpty) {
      stop();
      return;
    }
    final now = _now();
    if (!_own ||
        _lastSent == null ||
        now.difference(_lastSent!) >= const Duration(seconds: 2)) {
      _send(true);
      _lastSent = now;
    }
    _own = true;
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 4), stop);
  }

  void stop() {
    _idle?.cancel();
    if (_own) _send(false);
    _own = false;
    _lastSent = null;
  }

  @override
  void dispose() {
    stop();
    _poll?.cancel();
    _expiry?.cancel();
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}

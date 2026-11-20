import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/system_incoming_calls.dart';
import '../domain/entities/call_room.dart';
import 'call_cubit.dart';

/// Keeps one OS call paired with one server room, including remote cancellation.
class SystemCallController extends ChangeNotifier {
  SystemCallController(this.cubit, this.native, {required this.onOpen}) {
    native.listen(_event);
    _subscription = cubit.stream.listen((_) => _schedule());
    _schedule();
  }
  final CallCubit cubit;
  final SystemIncomingCalls native;
  final VoidCallback onOpen;
  late final StreamSubscription<CallState> _subscription;
  Future<void> _queue = Future.value();
  CallRoom? _shown;
  bool _visible = false, _accepted = false, _connected = false;
  bool? _muted;
  bool _disposed = false, _answering = false;
  final Set<String> _suppressed = {};
  bool get presenting => _visible;
  void _schedule() {
    _queue = _queue.then((_) => _sync()).catchError((Object _) {});
  }

  Future<void> _sync() async {
    if (_disposed) return;
    final state = cubit.state;
    final incoming = state.incoming;
    _suppressed.removeWhere((id) => id != incoming?.id && id != state.room?.id);
    final shown = _shown;
    if (shown != null) {
      final running = state.busy && state.room?.id == shown.id;
      if (!running && incoming?.id != shown.id) {
        _shown = null;
        _visible = false;
        _accepted = false;
        _connected = false;
        _muted = null;
        notifyListeners();
        await native.end(shown.id);
      } else if (running) {
        if (_visible && !_accepted) {
          _accepted = true;
          try {
            await native.answer(shown.id);
          } catch (_) {
            // Release CallKit's manual audio gate before continuing in-app.
            await native.end(shown.id).catchError((Object _) {});
            _visible = false;
            notifyListeners();
          }
        }
        if (state.phase == CallPhase.active) {
          if (!_connected) {
            _connected = true;
            await native.connected(shown.id);
          }
          final muted = !cubit.media.microphone;
          if (_muted != muted) {
            _muted = muted;
            await native.mute(shown.id, muted);
          }
        }
      }
    }
    if (_disposed || _shown != null || cubit.state.busy) return;
    final next = cubit.state.incoming;
    if (next == null || _suppressed.contains(next.id)) return;
    _shown = next;
    try {
      _visible = await native.show(next);
    } catch (_) {
      _visible = false;
    }
    if (_disposed) {
      await native.end(next.id);
      return;
    }
    notifyListeners();
    // Reconcile a remote end/answer that arrived while the native API awaited.
    if (cubit.state.incoming?.id != next.id) _schedule();
  }

  Future<void> answer(CallRoom room) async {
    if (_visible && _shown?.id == room.id) {
      try {
        await native.answer(room.id);
        return;
      } catch (_) {
        await native.end(room.id).catchError((Object _) {});
        _visible = false;
        notifyListeners();
      }
    }
    await _accept(room);
  }

  Future<void> _accept(CallRoom room) async {
    if (_answering || cubit.state.busy || cubit.state.incoming?.id != room.id) {
      return;
    }
    _answering = true;
    try {
      final pending = cubit.accept(room);
      onOpen();
      await pending;
    } finally {
      _answering = false;
      _schedule();
    }
  }

  Future<void> _event(String action, String id, bool muted) async {
    if (_disposed || id.isEmpty || _shown?.id != id) return;
    final incoming = cubit.state.incoming;
    switch (action) {
      case 'answer':
        _accepted = true;
        if (incoming?.id == id) await _accept(incoming!);
      case 'decline':
      case 'timeout':
        if (incoming?.id == id && !cubit.state.busy) {
          _suppressed.add(id);
          _visible = false;
          notifyListeners();
          await cubit.decline(incoming!);
        }
      case 'end':
      case 'reset':
        if (cubit.state.busy && cubit.state.room?.id == id) {
          await cubit.finish();
        } else if (incoming?.id == id) {
          _suppressed.add(id);
          await cubit.decline(incoming!);
        }
      case 'mute':
        _muted = muted;
        if (cubit.state.phase == CallPhase.active &&
            cubit.state.room?.id == id &&
            cubit.media.microphone == muted) {
          await cubit.control('microphone');
        }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    final id = _shown?.id;
    if (id != null) unawaited(native.end(id).catchError((Object _) {}));
    native.dispose();
    super.dispose();
  }
}

import 'package:flutter/gestures.dart';

/// A tap or two-finger gesture belongs to the map; a one-finger drag belongs
/// to its surrounding dashboard scroll view.
class MapGestureRecognizer extends OneSequenceGestureRecognizer {
  final Set<int> _pointers = {};
  final Map<int, Offset> _origins = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointers.add(event.pointer);
    _origins[event.pointer] = event.position;
    if (_pointers.length >= 2) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        _pointers.length == 1 &&
        (event.position - _origins[event.pointer]!).distance > kTouchSlop) {
      resolve(GestureDisposition.rejected);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      resolve(
        event is PointerUpEvent
            ? GestureDisposition.accepted
            : GestureDisposition.rejected,
      );
      _pointers.remove(event.pointer);
      _origins.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    resolve(GestureDisposition.rejected);
    _pointers.clear();
    _origins.clear();
  }

  @override
  String get debugDescription => 'map tap or two-finger interaction';
}

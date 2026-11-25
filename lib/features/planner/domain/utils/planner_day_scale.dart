import 'dart:math' as math;

/// The web planner's piecewise scale: readable tasks and compressed empty time.
class PlannerDayScale {
  PlannerDayScale(
    List<({double start, double end})> intervals,
    double viewport,
  ) {
    final busy = intervals
        .where((s) => s.start.isFinite && s.end.isFinite && s.end > s.start)
        .map(
          (s) => (
            start: s.start.clamp(0.0, 1440.0),
            end: s.end.clamp(0.0, 1440.0),
          ),
        )
        .where((s) => s.end > s.start)
        .toList();
    final start = viewport > 0
        ? math.max(0.0, busy.fold(360.0, (v, s) => math.min(v, s.start)) - 30)
        : 0.0;
    final end = viewport > 0
        ? math.min(1440.0, busy.fold(1080.0, (v, s) => math.max(v, s.end)) + 30)
        : 1440.0;
    final points = {
      start,
      end,
      ...busy.expand((s) => [s.start, s.end]),
    }.toList()..sort();
    for (var i = 0; i < points.length - 1; i++) {
      final from = points[i], to = points[i + 1];
      final active = busy.where((s) => s.start < to && s.end > from).toList();
      final rate = active.fold(
        active.isEmpty ? .2 : 128 / 60,
        (v, s) => math.max(v, 52 / (s.end - s.start)),
      );
      final minimum = active.fold(
        active.isEmpty ? .1 : 0.0,
        (v, s) => math.max(v, 32 / (s.end - s.start)),
      );
      _segments.add(_Segment(from, to, rate, minimum, active.isNotEmpty));
    }
    double sum() => _segments.fold(0.0, (v, s) => v + s.length * s.rate);
    if (viewport > 0 && sum() > viewport) {
      for (final occupied in [false, true]) {
        final savings = _segments
            .where((s) => s.occupied == occupied)
            .fold(0.0, (v, s) => v + s.length * (s.rate - s.minimum));
        final compression = savings > 0
            ? ((sum() - viewport) / savings).clamp(0.0, 1.0)
            : 0.0;
        for (final s in _segments.where((s) => s.occupied == occupied)) {
          s.rate -= (s.rate - s.minimum) * compression;
        }
      }
    }
    final emptyMinutes = _segments
        .where((s) => !s.occupied)
        .fold(0.0, (v, s) => v + s.length);
    final extra = emptyMinutes > 0
        ? math.max(0.0, viewport - sum()) / emptyMinutes
        : 0.0;
    for (final s in _segments) {
      if (!s.occupied) s.rate += extra;
      s.y = height;
      height += s.length * s.rate;
    }
  }
  final _segments = <_Segment>[];
  double height = 0;
  double toY(double minutes, {bool clamp = true}) {
    final m = clamp
        ? minutes.clamp(_segments.first.start, _segments.last.end)
        : minutes;
    final s = _segments.firstWhere(
      (s) => m <= s.end,
      orElse: () => _segments.last,
    );
    return s.y + (m - s.start) * s.rate;
  }

  double toMinutes(double y, {bool clamp = true}) {
    final position = clamp ? y.clamp(0.0, height) : y;
    final s = _segments.firstWhere(
      (s) => position <= s.y + s.length * s.rate,
      orElse: () => _segments.last,
    );
    return s.start + (position - s.y) / s.rate;
  }
}

class _Segment {
  _Segment(this.start, this.end, this.rate, this.minimum, this.occupied);
  final double start, end, minimum;
  final bool occupied;
  double rate, y = 0;
  double get length => end - start;
}

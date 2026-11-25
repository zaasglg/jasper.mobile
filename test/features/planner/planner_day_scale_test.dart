import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/planner/domain/utils/planner_day_scale.dart';

void main() {
  test('empty web day fills viewport with evenly spaced three-hour labels', () {
    final scale = PlannerDayScale([], 720);
    expect(scale.height, closeTo(720, .001));
    expect(scale.toY(360), closeTo(30.0 / 780 * 720, .001));
    expect(
      scale.toY(540) - scale.toY(360),
      closeTo(scale.toY(720) - scale.toY(540), .001),
    );
  });
  test('web occupied intervals expand while free time compresses', () {
    final scale = PlannerDayScale([
      (start: 360.0, end: 450.0),
      (start: 450.0, end: 480.0),
    ], 600);
    expect(scale.height, closeTo(600, .001));
    expect(
      scale.toY(450) - scale.toY(360),
      greaterThan(scale.toY(720) - scale.toY(630)),
    );
    for (final minute in [330.0, 360.0, 400.0, 450.0, 480.0, 900.0, 1110.0]) {
      expect(scale.toMinutes(scale.toY(minute)), closeTo(minute, .001));
    }
  });
  test('early and late tasks extend the web day range', () {
    final scale = PlannerDayScale([
      (start: 0.0, end: 30.0),
      (start: 1410.0, end: 1440.0),
    ], 600);
    expect(scale.toY(0), 0);
    expect(scale.toY(1440), closeTo(scale.height, .001));
    expect(scale.toY(1440) - scale.toY(1410), greaterThanOrEqualTo(32));
  });
}

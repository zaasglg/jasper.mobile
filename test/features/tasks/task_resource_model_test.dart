import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/features/tasks/data/models/task_detail_model.dart';

void main() {
  const resource = TaskResourceModel(
    id: 'a',
    name: 'Материал',
    planValue: 500,
    factValue: 300,
  );
  test('percentage is computed from actual and planned values', () {
    expect(resource.percentage, 60);
    expect(resource.copyWith(planValue: 0).percentage, 0);
    expect(resource.copyWith(factValue: 600).percentage, 120);
    expect(resource.copyWith(factValue: 400).isNearBudget, isTrue);
    expect(resource.copyWith(factValue: 600).isOverBudget, isTrue);
  });
  test('units round trip and older payloads use pieces', () {
    expect(TaskResourceModel.fromJson({'id': 'old'}).unit, ResourceUnit.pieces);
    final custom = resource.copyWith(
      unit: ResourceUnit.custom,
      customUnit: 'коробки',
    );
    expect(TaskResourceModel.fromJson(custom.toJson()), custom);
  });
}

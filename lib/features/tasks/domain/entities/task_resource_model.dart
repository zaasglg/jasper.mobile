import 'package:equatable/equatable.dart';

enum ResourceUnit {
  hours('ч'),
  days('дн'),
  personHours('чел·ч'),
  pieces('шт'),
  kilograms('кг'),
  liters('л'),
  tenge('₸'),
  custom('Своя единица');

  const ResourceUnit(this.label);
  final String label;
}

class TaskResourceModel extends Equatable {
  const TaskResourceModel({
    required this.id,
    required this.name,
    this.planValue = 0,
    this.factValue = 0,
    this.order = 0,
    this.unit = ResourceUnit.pieces,
    this.customUnit = '',
  });

  factory TaskResourceModel.fromJson(Map<String, dynamic> json) {
    return TaskResourceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      planValue: double.tryParse(json['planValue']?.toString() ?? '') ?? 0,
      factValue: double.tryParse(json['factValue']?.toString() ?? '') ?? 0,
      order: json['order'] is num
          ? (json['order'] as num).toInt()
          : int.tryParse(json['order']?.toString() ?? '') ?? 0,
      unit: ResourceUnit.values.firstWhere(
        (unit) => unit.name == json['unit'],
        orElse: () => ResourceUnit.pieces,
      ),
      customUnit: json['customUnit'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final double planValue;
  final double factValue;
  final int order;

  final ResourceUnit unit;
  final String customUnit;
  String get unitLabel => unit == ResourceUnit.custom ? customUnit : unit.label;

  double get ratio => planValue <= 0 ? 0 : factValue / planValue;
  double get percentage => ratio * 100;
  bool get isOverBudget => percentage > 100;
  bool get isNearBudget => percentage >= 80 && percentage <= 100;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'planValue': planValue,
    'factValue': factValue,
    'order': order,
    'unit': unit.name,
    'customUnit': customUnit,
  };

  TaskResourceModel copyWith({
    String? id,
    String? name,
    double? planValue,
    double? factValue,
    int? order,
    ResourceUnit? unit,
    String? customUnit,
  }) {
    return TaskResourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      planValue: planValue ?? this.planValue,
      factValue: factValue ?? this.factValue,
      order: order ?? this.order,
      unit: unit ?? this.unit,
      customUnit: customUnit ?? this.customUnit,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    planValue,
    factValue,
    order,
    unit,
    customUnit,
  ];
}

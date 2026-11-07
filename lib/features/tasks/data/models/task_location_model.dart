import 'package:equatable/equatable.dart';

class TaskLocationModel extends Equatable {
  const TaskLocationModel({
    required this.address,
    this.latitude,
    this.longitude,
  });
  final String address;
  final double? latitude, longitude;
  factory TaskLocationModel.fromJson(Map<String, dynamic> json) =>
      TaskLocationModel(
        address: json['address']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
  static TaskLocationModel? parse(Object? value) {
    if (value is! Map) return null;
    if ((value['latitude'] != null && value['latitude'] is! num) ||
        (value['longitude'] != null && value['longitude'] is! num)) {
      return null;
    }
    final result = TaskLocationModel.fromJson(Map<String, dynamic>.from(value));
    return result.valid ? result : null;
  }

  bool get valid =>
      address.trim().isNotEmpty &&
      address.trim().length <= 500 &&
      ((latitude == null && longitude == null) ||
          (latitude != null &&
              longitude != null &&
              latitude!.isFinite &&
              longitude!.isFinite &&
              latitude!.abs() <= 90 &&
              longitude!.abs() <= 180));
  Map<String, dynamic> toJson() => {
    'address': address.trim(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
  TaskLocationModel copyWith({
    String? address,
    double? latitude,
    double? longitude,
  }) => TaskLocationModel(
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
  Uri get link => Uri.https(
    'yandex.ru',
    '/maps/',
    latitude == null
        ? {'text': address}
        : {
            'll': '$longitude,$latitude',
            'pt': '$longitude,$latitude,pm2rdm',
            'z': '16',
          },
  );
  @override
  List<Object?> get props => [address, latitude, longitude];
}

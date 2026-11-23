import 'package:flutter/foundation.dart';

import 'trip_draft.dart';

/// A car from "Мои автомобили" (`GET /api/v1/cars`).
@immutable
class DriverCar {
  const DriverCar({
    required this.id,
    required this.brand,
    required this.model,
    required this.vehicleType,
    required this.seats,
    this.plate,
    this.photoUrl,
  });

  /// [mediaBaseUrl] turns the API's relative `/media/...` photo path into a URL.
  factory DriverCar.fromJson(
    Map<String, dynamic> json, {
    String mediaBaseUrl = '',
  }) {
    final photo = json['photo_url'] as String?;
    return DriverCar(
      id: json['id'] as String,
      brand: (json['brand'] as Map<String, dynamic>)['name'] as String,
      model: (json['model'] as Map<String, dynamic>)['name'] as String,
      vehicleType: json['vehicle_type'] == 'bus'
          ? VehicleType.bus
          : VehicleType.car,
      seats: json['seats'] as int,
      plate: json['plate'] as String?,
      photoUrl: photo == null ? null : '$mediaBaseUrl$photo',
    );
  }

  final String id;
  final String brand;
  final String model;
  final VehicleType vehicleType;

  /// Passenger seats (without the driver).
  final int seats;
  final String? plate;
  final String? photoUrl;

  String get title => '$brand $model';
}

/// "4 места", "1 место", "8 мест".
String seatsLabel(int n) {
  final word = n % 10 == 1 && n % 100 != 11
      ? 'место'
      : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
      ? 'места'
      : 'мест';
  return '$n $word';
}

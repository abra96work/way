import 'dart:async';

import 'package:geolocator/geolocator.dart';

class PassengerCoordinates {
  const PassengerCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

abstract interface class PassengerLocationService {
  Future<PassengerCoordinates?> requestCurrentPosition();
}

class GeolocatorPassengerLocationService implements PassengerLocationService {
  const GeolocatorPassengerLocationService();

  @override
  Future<PassengerCoordinates?> requestCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return PassengerCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      return null;
    } on PermissionDeniedException {
      return null;
    } on TimeoutException {
      return null;
    } on Exception {
      return null;
    }
  }
}

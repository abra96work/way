class PassengerTrip {
  const PassengerTrip({
    required this.id,
    required this.departureAt,
    required this.vehicleType,
    required this.driverName,
    required this.driverRating,
    required this.completedTrips,
    required this.driverAvatarUrl,
    required this.carName,
    required this.carPhotoUrl,
    required this.carPlate,
    required this.boardAddress,
    required this.alightAddress,
    required this.boardPosition,
    required this.alightPosition,
    required this.stopsCount,
    required this.distanceKm,
    required this.price,
    required this.seatsAvailable,
    required this.extras,
    required this.acceptsParcels,
    required this.isRegistrationOpen,
  });

  final String id;
  final DateTime departureAt;
  final String vehicleType;
  final String driverName;
  final double driverRating;
  final int completedTrips;
  final String? driverAvatarUrl;
  final String carName;
  final String? carPhotoUrl;
  final String? carPlate;
  final String boardAddress;
  final String alightAddress;
  final int boardPosition;
  final int alightPosition;
  final int stopsCount;
  final double? distanceKm;
  final int price;
  final int seatsAvailable;
  final List<String> extras;
  final bool acceptsParcels;
  final bool isRegistrationOpen;

  factory PassengerTrip.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['driver']);
    final car = _map(json['car']);
    final board = _map(json['board']);
    final alight = _map(json['alight']);
    final price = _map(json['price']);
    return PassengerTrip(
      id: json['trip_id'] as String? ?? '',
      departureAt:
          DateTime.tryParse(json['departure_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      vehicleType: json['vehicle_type'] as String? ?? 'car',
      driverName: _personName(driver),
      driverRating: (driver['rating'] as num?)?.toDouble() ?? 5,
      completedTrips: (driver['completed_trips'] as num?)?.toInt() ?? 0,
      driverAvatarUrl: driver['avatar_url'] as String?,
      carName: '${_catalogName(car['brand'])} ${_catalogName(car['model'])}'
          .trim(),
      carPhotoUrl: car['photo_url'] as String?,
      carPlate: car['plate'] as String?,
      boardAddress: board['address'] as String? ?? '',
      alightAddress: alight['address'] as String? ?? '',
      boardPosition: (board['position'] as num?)?.toInt() ?? 0,
      alightPosition: (alight['position'] as num?)?.toInt() ?? 1,
      stopsCount: (json['stops_count'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      price: (price['passenger_price'] as num?)?.toInt() ?? 0,
      seatsAvailable: (json['seats_available'] as num?)?.toInt() ?? 0,
      extras: _strings(json['extras']),
      acceptsParcels: json['accepts_parcels'] == true,
      isRegistrationOpen: json['is_registration_open'] != false,
    );
  }
}

class PassengerTripFilter {
  const PassengerTripFilter({
    this.fromQuery,
    this.toQuery,
    this.latitude,
    this.longitude,
    this.radiusKm = 30,
  }) : assert(
         (latitude == null && longitude == null) ||
             (latitude != null && longitude != null),
       );

  static const empty = PassengerTripFilter();

  final String? fromQuery;
  final String? toQuery;
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  bool get isActive =>
      fromQuery != null ||
      toQuery != null ||
      (latitude != null && longitude != null);

  bool get usesLocation => latitude != null && longitude != null;

  factory PassengerTripFilter.manual({String? from, String? to}) =>
      PassengerTripFilter(fromQuery: _nonEmpty(from), toQuery: _nonEmpty(to));

  factory PassengerTripFilter.nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
  }) => PassengerTripFilter(
    latitude: latitude,
    longitude: longitude,
    radiusKm: radiusKm,
  );

  Map<String, dynamic> toQueryParameters(String vehicleType) {
    return <String, dynamic>{
      'vehicle_type': vehicleType,
      if (fromQuery != null) 'from_query': fromQuery,
      if (toQuery != null) 'to_query': toQuery,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (usesLocation) 'radius_km': radiusKm,
    };
  }
}

class PassengerTripDetails {
  const PassengerTripDetails({
    required this.id,
    required this.departureAt,
    required this.driverName,
    required this.driverRating,
    required this.completedTrips,
    required this.driverAvatarUrl,
    required this.carName,
    required this.carPhotoUrl,
    required this.carPlate,
    required this.stops,
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.price,
    required this.extras,
    required this.parcelSizes,
    this.extraOptions = const [],
    this.parcelOptions = const [],
    this.segmentPrices = const [],
  });

  final String id;
  final DateTime departureAt;
  final String driverName;
  final double driverRating;
  final int completedTrips;
  final String? driverAvatarUrl;
  final String carName;
  final String? carPhotoUrl;
  final String? carPlate;
  final List<PassengerStop> stops;
  final int seatsTotal;
  final int seatsAvailable;
  final int price;
  final List<String> extras;
  final List<PassengerExtraOption> extraOptions;
  final List<String> parcelSizes;
  final List<PassengerParcelOption> parcelOptions;
  final List<PassengerSegmentPrice> segmentPrices;

  factory PassengerTripDetails.fromJson(Map<String, dynamic> json) {
    final driver = _map(json['driver']);
    final car = _map(json['car']);
    final fullPrice = _map(json['full_price']);
    final parcelOptions = (json['parcel_prices'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              PassengerParcelOption.fromJson(value.cast<String, dynamic>()),
        )
        .where((value) => value.size.isNotEmpty)
        .toList(growable: false);
    final extraOptions = (json['extras'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              PassengerExtraOption.fromJson(value.cast<String, dynamic>()),
        )
        .where((value) => value.kind.isNotEmpty)
        .toList(growable: false);
    return PassengerTripDetails(
      id: json['id'] as String? ?? '',
      departureAt:
          DateTime.tryParse(json['departure_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      driverName: _personName(driver),
      driverRating: (driver['rating'] as num?)?.toDouble() ?? 5,
      completedTrips: (driver['completed_trips'] as num?)?.toInt() ?? 0,
      driverAvatarUrl: driver['avatar_url'] as String?,
      carName: '${_catalogName(car['brand'])} ${_catalogName(car['model'])}'
          .trim(),
      carPhotoUrl: car['photo_url'] as String?,
      carPlate: car['plate'] as String?,
      stops: (json['stops'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => PassengerStop.fromJson(value.cast<String, dynamic>()))
          .toList(growable: false),
      seatsTotal: (json['seats_total'] as num?)?.toInt() ?? 0,
      seatsAvailable: (json['seats_available'] as num?)?.toInt() ?? 0,
      price: (fullPrice['passenger_price'] as num?)?.toInt() ?? 0,
      extras: (json['extras'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value['kind'])
          .whereType<String>()
          .toList(growable: false),
      extraOptions: extraOptions,
      parcelSizes: (json['parcel_prices'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value['size'])
          .whereType<String>()
          .toList(growable: false),
      parcelOptions: parcelOptions,
      segmentPrices: (json['segment_prices'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                PassengerSegmentPrice.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class PassengerExtraOption {
  const PassengerExtraOption({required this.kind, required this.price});

  final String kind;
  final int price;

  factory PassengerExtraOption.fromJson(Map<String, dynamic> json) {
    final price = _map(json['price']);
    return PassengerExtraOption(
      kind: json['kind'] as String? ?? '',
      price: (price['passenger_price'] as num?)?.toInt() ?? 0,
    );
  }
}

class PassengerParcelOption {
  const PassengerParcelOption({
    required this.size,
    required this.maxDimensionsCm,
    required this.maxWeightKg,
    required this.price,
  });

  final String size;
  final List<int> maxDimensionsCm;
  final int maxWeightKg;
  final int price;

  factory PassengerParcelOption.fromJson(Map<String, dynamic> json) {
    final price = _map(json['price']);
    return PassengerParcelOption(
      size: json['size'] as String? ?? '',
      maxDimensionsCm: (json['max_dimensions_cm'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      maxWeightKg: (json['max_weight_kg'] as num?)?.toInt() ?? 0,
      price: (price['passenger_price'] as num?)?.toInt() ?? 0,
    );
  }
}

class PassengerSegmentPrice {
  const PassengerSegmentPrice({
    required this.fromPosition,
    required this.toPosition,
    required this.price,
  });

  final int fromPosition;
  final int toPosition;
  final int price;

  factory PassengerSegmentPrice.fromJson(Map<String, dynamic> json) {
    final price = _map(json['price']);
    return PassengerSegmentPrice(
      fromPosition: (json['from_position'] as num?)?.toInt() ?? 0,
      toPosition: (json['to_position'] as num?)?.toInt() ?? 0,
      price: (price['passenger_price'] as num?)?.toInt() ?? 0,
    );
  }
}

class PassengerStop {
  const PassengerStop({required this.position, required this.address});

  final int position;
  final String address;

  factory PassengerStop.fromJson(Map<String, dynamic> json) => PassengerStop(
    position: (json['position'] as num?)?.toInt() ?? 0,
    address: json['address'] as String? ?? '',
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];

String _personName(Map<String, dynamic> value) {
  final first = value['first_name'] as String? ?? 'Водитель';
  final last = value['last_name'] as String?;
  if (last == null || last.trim().isEmpty) return first;
  return '$first ${last.trim()[0]}.';
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _catalogName(Object? value) {
  if (value is Map) return value['name']?.toString() ?? '';
  return value?.toString() ?? '';
}

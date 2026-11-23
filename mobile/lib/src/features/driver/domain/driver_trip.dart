import 'package:flutter/foundation.dart';

import 'driver_car.dart';
import 'trip_draft.dart';

/// A driver's trip as the API returns it (`TripRead`), only the fields the
/// driver screens use. Prices are the driver's own (without commission).
@immutable
class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.departureAt,
    required this.stops,
    required this.fullPrice,
    required this.carTitle,
    required this.bookingMode,
    this.arrivalAt,
    this.vehicleType = VehicleType.car,
    this.segmentPrices = const {},
    this.extras = const {},
    this.parcelSizes = const [],
    this.carPlate,
    this.returnOfTripId,
  });

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    int driverPrice(Object? price) =>
        (price as Map<String, dynamic>)['driver_price'] as int;
    final car = json['car'] as Map<String, dynamic>;
    final arrival = json['arrival_at'] as String?;
    return DriverTrip(
      id: json['id'] as String,
      departureAt: DateTime.parse(json['departure_at'] as String).toLocal(),
      arrivalAt: arrival == null ? null : DateTime.parse(arrival).toLocal(),
      vehicleType: json['vehicle_type'] == 'bus'
          ? VehicleType.bus
          : VehicleType.car,
      stops: [
        for (final s in json['stops'] as List)
          (s as Map<String, dynamic>)['address'] as String,
      ],
      fullPrice: driverPrice(json['full_price']),
      segmentPrices: {
        for (final p in json['segment_prices'] as List? ?? const [])
          ((p as Map)['from_position'] as int, p['to_position'] as int):
              driverPrice(p['price']),
      },
      extras: {
        for (final e in json['extras'] as List? ?? const [])
          TripExtraKind.values.firstWhere((k) => k.value == (e as Map)['kind']):
              driverPrice((e as Map)['price']),
      },
      parcelSizes: [
        for (final p in json['parcel_prices'] as List? ?? const [])
          ParcelSize.values.firstWhere((s) => s.value == (p as Map)['size']),
      ],
      carTitle:
          '${(car['brand'] as Map)['name']} ${(car['model'] as Map)['name']}',
      carPlate: car['plate'] as String?,
      bookingMode: json['booking_mode'] == 'instant'
          ? BookingMode.instant
          : BookingMode.manual,
      returnOfTripId: json['return_of_trip_id'] as String?,
    );
  }

  final String id;

  /// Local time.
  final DateTime departureAt;
  final DateTime? arrivalAt;
  final VehicleType vehicleType;

  /// Addresses from departure to destination.
  final List<String> stops;
  final int fullPrice;

  /// Prices between stop positions, `(from, to)`.
  final Map<(int, int), int> segmentPrices;
  final Map<TripExtraKind, int> extras;
  final List<ParcelSize> parcelSizes;
  final String carTitle;
  final String? carPlate;
  final BookingMode bookingMode;

  /// Set when this trip is the way back of another one.
  final String? returnOfTripId;

  bool get isReturnTrip => returnOfTripId != null;

  /// Stops of the way back.
  List<String> get reversedStops => stops.reversed.toList();

  /// Price of `from → to` on the way back (positions of [reversedStops]).
  int? reversedSegmentPrice(int from, int to) {
    final last = stops.length - 1;
    return segmentPrices[(last - to, last - from)];
  }
}

/// What the driver is about to publish, for the "Опубликовать поездку?" sheet.
@immutable
class TripPreview {
  const TripPreview({
    required this.stops,
    required this.departureAt,
    required this.fullPrice,
    required this.segmentPrices,
    required this.extras,
    required this.parcelSizes,
    required this.carTitle,
    required this.bookingMode,
  });

  factory TripPreview.fromDraft(TripDraft draft) {
    final stops = draft.stops;
    return TripPreview(
      stops: [for (final s in stops) s.text.trim()],
      departureAt: draft.departureAt!,
      fullPrice: draft.fullPrice ?? 0,
      segmentPrices: draft.needsSegmentPrices
          ? [for (final (a, b) in draft.segments) draft.segmentPrice(a, b) ?? 0]
          : const [],
      extras: {for (final kind in draft.extras) kind: kind.price},
      parcelSizes: [
        for (final size in ParcelSize.values)
          if (draft.parcelSizes.contains(size)) size,
      ],
      carTitle: draft.car == null ? '—' : carLabel(draft.car!),
      bookingMode: draft.bookingMode ?? BookingMode.manual,
    );
  }

  /// The way back of [trip], leaving at [departureAt].
  factory TripPreview.reverseOf(DriverTrip trip, DateTime departureAt) {
    final stops = trip.reversedStops;
    return TripPreview(
      stops: stops,
      departureAt: departureAt,
      fullPrice: trip.fullPrice,
      segmentPrices: stops.length > 2
          ? [
              for (var i = 0; i + 1 < stops.length; i++)
                trip.reversedSegmentPrice(i, i + 1) ?? 0,
            ]
          : const [],
      extras: trip.extras,
      parcelSizes: trip.parcelSizes,
      carTitle: trip.carPlate == null
          ? trip.carTitle
          : '${trip.carTitle}, ${trip.carPlate}',
      bookingMode: trip.bookingMode,
    );
  }

  final List<String> stops;
  final DateTime departureAt;
  final int fullPrice;

  /// Prices between consecutive [stops]; empty for a direct trip.
  final List<int> segmentPrices;
  final Map<TripExtraKind, int> extras;
  final List<ParcelSize> parcelSizes;
  final String carTitle;
  final BookingMode bookingMode;

  int get extrasPrice => extras.values.fold(0, (sum, p) => sum + p);
}

/// "Toyota Camry, 7841НХ-7".
String carLabel(DriverCar car) => car.plate == null || car.plate!.isEmpty
    ? car.title
    : '${car.title}, ${car.plate}';

/// `GET /trips/limits`: daily and weekly publishing limits.
@immutable
class PublishLimits {
  const PublishLimits({
    required this.date,
    required this.dayUsed,
    required this.dayLimit,
    required this.weekUsed,
    required this.weekLimit,
  });

  factory PublishLimits.fromJson(Map<String, dynamic> json) {
    final day = json['day'] as Map<String, dynamic>;
    final week = json['week'] as Map<String, dynamic>;
    return PublishLimits(
      date: DateTime.parse(json['date'] as String),
      dayUsed: day['used'] as int,
      dayLimit: day['limit'] as int,
      weekUsed: week['used'] as int,
      weekLimit: week['limit'] as int,
    );
  }

  final DateTime date;
  final int dayUsed;
  final int dayLimit;
  final int weekUsed;
  final int weekLimit;
}

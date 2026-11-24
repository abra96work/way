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
    this.number,
    this.status = TripStatus.published,
    this.seatsTotal = 0,
    this.seatsAvailable = 0,
    this.requestsCount = 0,
    this.requestAvatars = const [],
    this.driver,
    this.carPhotoUrl,
    this.isEditable = false,
    this.acceptsBookings = true,
    this.stopCities = const [],
    this.carId,
    this.minPrice = 0,
  });

  /// [mediaBaseUrl] turns relative `/media/...` avatar paths into URLs.
  factory DriverTrip.fromJson(
    Map<String, dynamic> json, {
    String mediaBaseUrl = '',
  }) {
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
      number: json['number'] as int?,
      status: TripStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TripStatus.published,
      ),
      seatsTotal: json['seats_total'] as int? ?? 0,
      seatsAvailable: json['seats_available'] as int? ?? 0,
      driver: json['driver'] == null
          ? null
          : TripPerson.fromJson(
              json['driver'] as Map<String, dynamic>,
              mediaBaseUrl: mediaBaseUrl,
            ),
      carPhotoUrl: car['photo_url'] == null
          ? null
          : '$mediaBaseUrl${car['photo_url']}',
      isEditable: json['is_editable'] as bool? ?? false,
      acceptsBookings: json['accepts_bookings'] as bool? ?? true,
      stopCities: [
        for (final s in json['stops'] as List)
          if ((s as Map)['city'] is Map)
            City(
              id: (s['city'] as Map)['id'] as int,
              name: (s['city'] as Map)['name'] as String,
            ),
      ],
      carId: car['id'] as String?,
      minPrice: json['min_price'] == null ? 0 : driverPrice(json['min_price']),
      requestsCount: (json['requests'] as Map?)?['count'] as int? ?? 0,
      requestAvatars: [
        for (final a in (json['requests'] as Map?)?['avatars'] as List? ?? [])
          '$mediaBaseUrl$a',
      ],
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

  /// "Заказ №1231".
  final int? number;
  final TripStatus status;
  final int seatsTotal;
  final int seatsAvailable;

  /// The driver as passengers see them (name, photo, rating).
  final TripPerson? driver;
  final String? carPhotoUrl;

  /// Route, time and prices can change: nobody has joined yet.
  final bool isEditable;

  /// false after «Завершить приём пассажиров».
  final bool acceptsBookings;

  /// City of each stop (same order as [stops]); needed to edit the route.
  final List<City> stopCities;
  final String? carId;

  /// "Стоимость посадки", the driver's own price.
  final int minPrice;

  /// Active requests and bookings (only in "Мои заказы").
  final int requestsCount;
  final List<String> requestAvatars;

  /// Stops of the way back.
  List<String> get reversedStops => stops.reversed.toList();

  /// Price of `from → to` on the way back (positions of [reversedStops]).
  int? reversedSegmentPrice(int from, int to) {
    final last = stops.length - 1;
    return segmentPrices[(last - to, last - from)];
  }
}

/// A person in a trip card: the driver or a passenger (`RatedUser`).
@immutable
class TripPerson {
  const TripPerson({
    required this.id,
    required this.firstName,
    this.lastName,
    this.avatarUrl,
    this.rating = 5,
    this.reviewsCount = 0,
    this.completedTrips = 0,
  });

  factory TripPerson.fromJson(
    Map<String, dynamic> json, {
    String mediaBaseUrl = '',
  }) {
    final avatar = json['avatar_url'] as String?;
    return TripPerson(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      avatarUrl: avatar == null ? null : '$mediaBaseUrl$avatar',
      rating: (json['rating'] as num?)?.toDouble() ?? 5,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      completedTrips: json['completed_trips'] as int? ?? 0,
    );
  }

  final String id;
  final String firstName;
  final String? lastName;
  final String? avatarUrl;
  final double rating;
  final int reviewsCount;
  final int completedTrips;

  /// "Виктор О."
  String get shortName {
    final last = lastName?.trim() ?? '';
    final name = firstName.trim().isEmpty ? 'Без имени' : firstName.trim();
    return last.isEmpty ? name : '$name ${last[0]}.';
  }

  /// "4,8"
  String get ratingLabel => rating.toStringAsFixed(1).replaceAll('.', ',');
}

/// Booking status as the driver sees it.
enum TripBookingStatus {
  pending('Ждёт подтверждения'),
  awaitingPayment('Ждёт оплаты'),
  paid('Оплачено'),
  completed('Поездка завершена'),
  rejected('Отклонена'),
  cancelled('Отменена');

  const TripBookingStatus(this.label);

  final String label;

  static TripBookingStatus parse(String? value) => switch (value) {
    'awaiting_payment' => awaitingPayment,
    'paid' => paid,
    'completed' => completed,
    'rejected' => rejected,
    'cancelled' => cancelled,
    _ => pending,
  };

  /// Still in the trip (shown in "Пассажиры").
  bool get isActive => this != rejected && this != cancelled;
}

/// A seat or parcel booking of the driver's trip (`GET /trips/{id}/bookings`).
@immutable
class TripBooking {
  const TripBooking({
    required this.id,
    required this.passenger,
    required this.status,
    this.seats = 1,
    this.parcelSize,
    this.phone,
    this.boardAddress,
    this.alightAddress,
    this.driverPrice,
  });

  factory TripBooking.fromJson(
    Map<String, dynamic> json, {
    String mediaBaseUrl = '',
  }) {
    final size = json['parcel_size'] as String?;
    return TripBooking(
      id: json['id'] as String,
      passenger: TripPerson.fromJson(
        json['passenger'] as Map<String, dynamic>,
        mediaBaseUrl: mediaBaseUrl,
      ),
      status: TripBookingStatus.parse(json['status'] as String?),
      seats: json['seats'] as int? ?? 1,
      parcelSize: size == null
          ? null
          : ParcelSize.values.firstWhere((s) => s.value == size),
      phone: json['passenger_phone'] as String?,
      boardAddress: (json['board'] as Map?)?['address'] as String?,
      alightAddress: (json['alight'] as Map?)?['address'] as String?,
      driverPrice: (json['price'] as Map?)?['driver_price'] as int?,
    );
  }

  /// Where the passenger gets on and off ("Маршрут пассажира").
  final String? boardAddress;
  final String? alightAddress;

  /// What the driver gets for this booking (seats and extras, no commission).
  final int? driverPrice;

  final String id;
  final TripPerson passenger;

  /// The passenger's phone: the backend sends it only after payment.
  final String? phone;
  final TripBookingStatus status;
  final int seats;

  /// Set for a parcel (no seat taken).
  final ParcelSize? parcelSize;

  /// "2 места", "Посылка S".
  String get what => parcelSize != null
      ? 'Посылка ${parcelSize!.value}'
      : seats == 1
      ? '1 место'
      : seats < 5
      ? '$seats места'
      : '$seats мест';
}

/// `status` of `TripRead`; "completed" is computed by the backend.
enum TripStatus { draft, published, completed, cancelled }

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

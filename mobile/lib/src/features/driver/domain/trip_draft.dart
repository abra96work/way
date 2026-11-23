import 'package:flutter/material.dart';

import 'driver_car.dart';

/// Vehicle type of a trip, as the backend names it (`vehicle_type`).
enum VehicleType {
  car('car', maxSeats: 8),
  bus('bus', maxSeats: 60);

  const VehicleType(this.apiValue, {required this.maxSeats});

  final String apiValue;

  /// Passenger seats limit the backend enforces for this type.
  final int maxSeats;
}

/// Extras the driver offers to seat bookings (`trips.extras`).
enum TripExtraKind {
  childSeat('child_seat', 'Детское кресло'),
  luggage('luggage', 'Багаж'),
  pets('pets', 'Животные');

  const TripExtraKind(this.value, this.title);

  final String value;
  final String title;

  /// Fixed price from the design, whole rubles without commission.
  int get price => 150;
}

/// Parcel sizes (`ParcelSize` on the backend, limits in `PARCEL_LIMITS`).
enum ParcelSize {
  s('S', 'Маленькая', 'Конверты, ключи…', 150),
  m('M', 'Средняя', 'до 50×40×30 см, до 10 кг', 250),
  l('L', 'Большая', 'до 80×60×50 см, до 30 кг', 350);

  const ParcelSize(this.value, this.title, this.hint, this.price);

  final String value;
  final String title;
  final String hint;

  /// Fixed price from the design, whole rubles without commission.
  final int price;
}

enum BookingMode {
  /// "Стандартное": the driver confirms each request.
  manual('manual'),

  /// "Быстрое бронирование": the passenger pays at once.
  instant('instant');

  const BookingMode(this.value);

  final String value;
}

/// A settlement from `GET /api/v1/cities`.
@immutable
class City {
  const City({required this.id, required this.name, this.region = ''});

  factory City.fromJson(Map<String, dynamic> json) => City(
    id: json['id'] as int,
    name: json['name'] as String,
    region: (json['region'] as String?) ?? '',
  );

  final int id;
  final String name;
  final String region;

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Lower-case and "ё" → "е", for matching Russian place names.
String foldName(String value) => value.toLowerCase().replaceAll('ё', 'е');

/// Finds the city named in a free-text address like "Победителей 1, Минск":
/// the last comma-separated part that equals a known city name.
City? detectCity(String text, List<City> cities) {
  final parts = text.split(',').map((p) => foldName(p.trim())).toList();
  for (final part in parts.reversed) {
    if (part.isEmpty) continue;
    for (final city in cities) {
      if (foldName(city.name) == part) return city;
    }
  }
  return null;
}

/// One point of the route as the driver types it: free text ("Победителей 1,
/// Минск") plus the city recognised in it. The backend needs that city's id.
@immutable
class RouteStop {
  const RouteStop({required this.id, this.text = '', this.city});

  /// Stable key for the input row, survives inserts and removals.
  final int id;
  final String text;
  final City? city;

  bool get isEmpty => text.trim().isEmpty;
  bool get isComplete => city != null && text.trim().length >= 2;

  RouteStop copyWith({required String text, required City? city}) =>
      RouteStop(id: id, text: text, city: city);

  Map<String, dynamic> toJson() => {
    'city_id': city!.id,
    'address': text.trim(),
  };
}

/// Data the driver fills in across the six "Новый заказ" steps.
///
/// Lives for one pass through the wizard; the last step turns it into a
/// `POST /api/v1/trips` request.
class TripDraft extends ChangeNotifier {
  TripDraft() {
    _stops = [_newStop(), _newStop()];
  }

  static const maxStops = 10;

  /// Publishing window from the requirements: "не дальше 3 дней"
  /// (backend `PUT_TRIP_PUBLISH_DAYS_AHEAD`).
  static const maxDaysAhead = 3;

  /// Departure later than [maxDaysAhead] days from [now] is refused.
  static bool isTooFar(DateTime departure, DateTime now) =>
      departure.isAfter(now.add(const Duration(days: maxDaysAhead)));

  int _nextStopId = 0;
  VehicleType _vehicleType = VehicleType.car;
  late List<RouteStop> _stops;
  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;
  int _seats = 0;

  RouteStop _newStop() => RouteStop(id: _nextStopId++);

  // ---------- step 1 ----------

  /// Filters which cars from "Мои автомобили" can be picked later.
  VehicleType get vehicleType => _vehicleType;

  set vehicleType(VehicleType value) {
    if (value == _vehicleType) return;
    _vehicleType = value;
    if (_seats > value.maxSeats) _seats = value.maxSeats;
    notifyListeners();
  }

  // ---------- step 2: route ----------

  /// Departure, intermediate stops, destination.
  List<RouteStop> get stops => List.unmodifiable(_stops);

  bool get canAddStop => _stops.length < maxStops;

  void updateStop(int index, {required String text, required City? city}) {
    final current = _stops[index];
    if (current.text == text && current.city == city) return;
    _stops = [..._stops]..[index] = current.copyWith(text: text, city: city);
    notifyListeners();
  }

  /// Adds an empty intermediate stop right before the destination.
  void addStop() {
    if (!canAddStop) return;
    _stops = [..._stops]..insert(_stops.length - 1, _newStop());
    notifyListeners();
  }

  void removeStop(int index) {
    if (index == 0 || index == _stops.length - 1) return;
    _stops = [..._stops]..removeAt(index);
    notifyListeners();
  }

  bool get sameOriginAndDestination =>
      _stops.first.city != null && _stops.first.city == _stops.last.city;

  // ---------- step 2: time ----------

  /// Local calendar date of departure (time part ignored).
  DateTime? get departureDate => _departureDate;
  TimeOfDay? get departureTime => _departureTime;
  TimeOfDay? get arrivalTime => _arrivalTime;

  set departureDate(DateTime? value) {
    _departureDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  set departureTime(TimeOfDay? value) {
    _departureTime = value;
    notifyListeners();
  }

  set arrivalTime(TimeOfDay? value) {
    _arrivalTime = value;
    notifyListeners();
  }

  /// Departure as a local date-time, once both parts are chosen.
  DateTime? get departureAt {
    final date = _departureDate;
    final time = _departureTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Arrival as a local date-time; an earlier clock time means the next day.
  DateTime? get arrivalAt {
    final departure = departureAt;
    final time = _arrivalTime;
    if (departure == null || time == null) return null;
    var arrival = DateTime(
      departure.year,
      departure.month,
      departure.day,
      time.hour,
      time.minute,
    );
    if (!arrival.isAfter(departure)) {
      arrival = arrival.add(const Duration(days: 1));
    }
    return arrival;
  }

  // ---------- step 2: seats ----------

  int get seats => _seats;

  set seats(int value) {
    final clamped = value.clamp(0, _vehicleType.maxSeats);
    if (clamped == _seats) return;
    _seats = clamped;
    notifyListeners();
  }

  /// Everything step 2 needs before "Далее".
  bool isRouteStepComplete(DateTime now) {
    final departure = departureAt;
    return _stops.every((s) => s.isComplete) &&
        !sameOriginAndDestination &&
        departure != null &&
        departure.isAfter(now) &&
        !isTooFar(departure, now) &&
        _seats >= 1;
  }

  // ---------- step 3: prices (driver's, whole rubles, no commission) ----------

  int? _fullPrice;
  int? _minPrice;
  final Map<String, int> _segmentPrices = {};

  /// Price of the whole route → `full_price`.
  int? get fullPrice => _fullPrice;

  set fullPrice(int? value) {
    _fullPrice = value;
    notifyListeners();
  }

  /// "Стоимость посадки" → `min_price`; empty means 0.
  int? get minPrice => _minPrice;

  set minPrice(int? value) {
    _minPrice = value;
    notifyListeners();
  }

  /// Consecutive pairs of stops (only asked for when there are stops between).
  List<(RouteStop, RouteStop)> get segments => [
    for (var i = 0; i + 1 < _stops.length; i++) (_stops[i], _stops[i + 1]),
  ];

  bool get needsSegmentPrices => _stops.length > 2;

  // Keyed by stop ids, so prices survive edits of the route on step 2.
  static String _segmentKey(RouteStop a, RouteStop b) => '${a.id}-${b.id}';

  int? segmentPrice(RouteStop from, RouteStop to) =>
      _segmentPrices[_segmentKey(from, to)];

  void setSegmentPrice(RouteStop from, RouteStop to, int? price) {
    final key = _segmentKey(from, to);
    if (price == null) {
      _segmentPrices.remove(key);
    } else {
      _segmentPrices[key] = price;
    }
    notifyListeners();
  }

  bool get minPriceTooHigh =>
      _fullPrice != null && _minPrice != null && _minPrice! > _fullPrice!;

  bool get isPriceStepComplete =>
      (_fullPrice ?? 0) >= 1 &&
      !minPriceTooHigh &&
      (!needsSegmentPrices ||
          segments.every((s) => (segmentPrice(s.$1, s.$2) ?? 0) >= 1));

  // ---------- step 4: car ----------

  String? _carId;
  DriverCar? _car;

  String? get carId => _carId;

  set carId(String? value) {
    if (value == _carId) return;
    _carId = value;
    if (_car?.id != value) _car = null;
    notifyListeners();
  }

  /// The chosen car itself, for the summary before publishing.
  DriverCar? get car => _car;

  set car(DriverCar? value) {
    _car = value;
    _carId = value?.id;
    notifyListeners();
  }

  // ---------- step 5: extras and parcels ----------

  final Set<TripExtraKind> _extras = {};
  final Set<ParcelSize> _parcelSizes = {};

  Set<TripExtraKind> get extras => Set.unmodifiable(_extras);

  void setExtra(TripExtraKind kind, bool offered) {
    final changed = offered ? _extras.add(kind) : _extras.remove(kind);
    if (changed) notifyListeners();
  }

  /// Parcel sizes the driver takes; empty — no parcels.
  Set<ParcelSize> get parcelSizes => Set.unmodifiable(_parcelSizes);

  set parcelSizes(Set<ParcelSize> value) {
    _parcelSizes
      ..clear()
      ..addAll(value);
    notifyListeners();
  }

  // ---------- step 6: booking mode ----------

  BookingMode? _bookingMode;

  BookingMode? get bookingMode => _bookingMode;

  set bookingMode(BookingMode? value) {
    if (value == _bookingMode) return;
    _bookingMode = value;
    notifyListeners();
  }

  /// Body of `POST /api/v1/trips`. Times go out in UTC; prices are the
  /// driver's own (the backend adds the commission). [publish] `false`
  /// saves a draft ("Сохранить шаблон").
  Map<String, dynamic> toCreateTripJson({bool publish = true}) {
    final segmentPrices = needsSegmentPrices
        ? [
            for (var i = 0; i + 1 < _stops.length; i++)
              {
                'from_position': i,
                'to_position': i + 1,
                'price': segmentPrice(_stops[i], _stops[i + 1]),
              },
          ]
        : const <Map<String, dynamic>>[];
    return {
      'car_id': _carId,
      'departure_at': departureAt!.toUtc().toIso8601String(),
      if (arrivalAt != null) 'arrival_at': arrivalAt!.toUtc().toIso8601String(),
      'seats_total': _seats,
      'stops': [for (final stop in _stops) stop.toJson()],
      'full_price': _fullPrice,
      'min_price': _minPrice ?? 0,
      'segment_prices': segmentPrices,
      'booking_mode': (_bookingMode ?? BookingMode.manual).value,
      'extras': [
        for (final kind in TripExtraKind.values)
          if (_extras.contains(kind)) {'kind': kind.value, 'price': kind.price},
      ],
      'parcel_prices': [
        for (final size in ParcelSize.values)
          if (_parcelSizes.contains(size))
            {'size': size.value, 'price': size.price},
      ],
      'publish': publish,
    };
  }

  /// Start a new trip from scratch.
  void reset() {
    _carId = null;
    _car = null;
    _vehicleType = VehicleType.car;
    _stops = [_newStop(), _newStop()];
    _departureDate = null;
    _departureTime = null;
    _arrivalTime = null;
    _seats = 0;
    _fullPrice = null;
    _minPrice = null;
    _segmentPrices.clear();
    _extras.clear();
    _parcelSizes.clear();
    _bookingMode = null;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_car.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/car_step_page.dart';

const _minsk = City(id: 1, name: 'Минск');
const _komsomolsk = City(id: 3, name: 'Жодино');
const _mogilev = City(id: 2, name: 'Могилев');

const _camry = DriverCar(
  id: 'c1',
  brand: 'Toyota',
  model: 'Camry',
  vehicleType: VehicleType.car,
  seats: 4,
  plate: '7841НХ-7',
);
const _largus = DriverCar(
  id: 'c2',
  brand: 'Lada',
  model: 'Largus',
  vehicleType: VehicleType.car,
  seats: 2,
);
const _paz = DriverCar(
  id: 'b1',
  brand: 'ПАЗ',
  model: '3205',
  vehicleType: VehicleType.bus,
  seats: 30,
);

Finder _key(String key) => find.byKey(ValueKey(key));

TripDraft _draft({int seats = 3}) {
  final draft = TripDraft()..addStop();
  draft
    ..updateStop(0, text: 'Победителей 1, Минск', city: _minsk)
    ..updateStop(1, text: 'Центр, Жодино', city: _komsomolsk)
    ..updateStop(2, text: 'Рынок местный, Могилев', city: _mogilev)
    ..departureDate = DateTime(2026, 11, 25)
    ..departureTime = const TimeOfDay(hour: 9, minute: 0)
    ..arrivalTime = const TimeOfDay(hour: 12, minute: 30)
    ..seats = seats
    ..fullPrice = 1200
    ..minPrice = 150;
  final s = draft.stops;
  draft
    ..setSegmentPrice(s[0], s[1], 600)
    ..setSegmentPrice(s[1], s[2], 700);
  return draft;
}

Future<void> _pump(
  WidgetTester tester,
  TripDraft draft, {
  List<DriverCar> cars = const [_camry, _largus, _paz],
  VoidCallback? onNext,
  Future<void> Function()? onAddCar,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: CarStepPage(
        draft: draft,
        loadCars: () async => cars,
        onNext: onNext ?? () {},
        onAddCar: onAddCar,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton _next(WidgetTester tester) =>
    tester.widget<FilledButton>(_key('new-trip-next'));

void main() {
  testWidgets('shows the summary and only cars of the chosen type', (
    tester,
  ) async {
    await _pump(tester, _draft());

    expect(find.text('Шаг 4 из 6'), findsOneWidget);
    expect(find.text('Вы получите'), findsOneWidget);
    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('7841НХ-7 • 4 места'), findsOneWidget);
    expect(find.text('ПАЗ 3205'), findsNothing);
    expect(_next(tester).onPressed, isNull);
  });

  testWidgets('selecting a car enables "Далее"', (tester) async {
    final draft = _draft();
    var next = 0;
    await _pump(tester, draft, onNext: () => next++);

    await tester.tap(_key('car-c1'));
    await tester.pump();

    expect(draft.carId, 'c1');
    await tester.tap(_key('new-trip-next'));
    expect(next, 1);
  });

  testWidgets('a car with fewer seats than passengers cannot be chosen', (
    tester,
  ) async {
    final draft = _draft();
    await _pump(tester, draft);

    expect(find.textContaining('нужно мест: 3'), findsOneWidget);
    await tester.tap(_key('car-c2'));
    await tester.pump();

    expect(draft.carId, isNull);
  });

  testWidgets('empty list shows the empty state with "Добавить авто"', (
    tester,
  ) async {
    var added = 0;
    await _pump(
      tester,
      _draft(),
      cars: const [],
      onAddCar: () async => added++,
    );

    expect(find.text('Нет добавленных авто'), findsOneWidget);
    await tester.tap(_key('car-add-empty'));
    await tester.pumpAndSettle();
    expect(added, 1);
  });

  testWidgets('bus trip without buses says so', (tester) async {
    final draft = _draft()..vehicleType = VehicleType.bus;
    await _pump(tester, draft, cars: const [_camry]);

    expect(find.text('Нет добавленных автобусов'), findsOneWidget);
  });

  test('builds the POST /trips body the backend expects', () {
    final draft = _draft()..carId = 'c1';

    final body = draft.toCreateTripJson();

    expect(body['car_id'], 'c1');
    expect(
      body['departure_at'],
      DateTime(2026, 11, 25, 9).toUtc().toIso8601String(),
    );
    expect(body['departure_at'], endsWith('Z'));
    expect(
      body['arrival_at'],
      DateTime(2026, 11, 25, 12, 30).toUtc().toIso8601String(),
    );
    expect(body['seats_total'], 3);
    expect(body['stops'], [
      {'city_id': 1, 'address': 'Победителей 1, Минск'},
      {'city_id': 3, 'address': 'Центр, Жодино'},
      {'city_id': 2, 'address': 'Рынок местный, Могилев'},
    ]);
    expect(body['full_price'], 1200);
    expect(body['min_price'], 150);
    expect(body['segment_prices'], [
      {'from_position': 0, 'to_position': 1, 'price': 600},
      {'from_position': 1, 'to_position': 2, 'price': 700},
    ]);
    expect(body['booking_mode'], 'manual');
    expect(body['extras'], isEmpty);
    expect(body['parcel_prices'], isEmpty);
    expect(body['publish'], isTrue);
  });

  test('car json maps photo to an absolute url', () {
    final car = DriverCar.fromJson({
      'id': 'c1',
      'brand': {'id': 1, 'name': 'Toyota'},
      'model': {'id': 2, 'name': 'Camry'},
      'vehicle_type': 'car',
      'seats': 4,
      'plate': 'А777АА66',
      'photo_url': '/media/cars/x.jpg',
    }, mediaBaseUrl: 'https://api.example');

    expect(car.title, 'Toyota Camry');
    expect(car.photoUrl, 'https://api.example/media/cars/x.jpg');
  });

  test('seats label declines', () {
    expect(seatsLabel(1), '1 место');
    expect(seatsLabel(4), '4 места');
    expect(seatsLabel(8), '8 мест');
    expect(seatsLabel(12), '12 мест');
    expect(seatsLabel(22), '22 места');
  });
}

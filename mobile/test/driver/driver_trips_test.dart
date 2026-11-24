import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_trip.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/trips/driver_trips_page.dart';
import 'package:put/src/features/driver/presentation/widgets/driver_nav_bar.dart';
import 'package:put/src/features/driver/presentation/widgets/price_summary.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

DriverTrip _trip({
  String id = 't1',
  TripStatus status = TripStatus.published,
  int requests = 0,
  Map<TripExtraKind, int> extras = const {},
  List<ParcelSize> parcels = const [],
  DateTime? arrival,
}) => DriverTrip(
  id: id,
  number: 1231,
  status: status,
  departureAt: DateTime(2026, 5, 16, 12),
  arrivalAt: arrival,
  stops: const ['Улица Солнечная, дом 12', 'Улица Лунная, дом 5'],
  fullPrice: 600,
  carTitle: 'Toyota Camry',
  bookingMode: BookingMode.manual,
  seatsTotal: 1,
  extras: extras,
  parcelSizes: parcels,
  requestsCount: requests,
);

Future<void> _pump(
  WidgetTester tester,
  Future<List<DriverTrip>> Function(DriverTripsTab) load, {
  VoidCallback? onCreate,
  Future<void> Function(DriverTrip)? onOpen,
  ValueChanged<DriverTab>? onTab,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: DriverTripsPage(
        loadTrips: load,
        onCreate: onCreate ?? () {},
        onTab: onTab ?? (_) {},
        onOpenTrip: onOpen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no trips: empty state with "Создать заказ"', (tester) async {
    var created = 0;
    await _pump(tester, (_) async => const [], onCreate: () => created++);

    expect(find.text('Мои заказы'), findsWidgets);
    expect(find.text('У вас пока нет поездок'), findsOneWidget);
    await tester.tap(_key('trips-create'));
    expect(created, 1);
  });

  testWidgets('card shows route, arrival, extras, requests, date, price', (
    tester,
  ) async {
    await _pump(
      tester,
      (_) async => [
        _trip(
          arrival: DateTime(2026, 5, 16, 15),
          extras: const {TripExtraKind.pets: 150, TripExtraKind.childSeat: 150},
          requests: 3,
        ),
        _trip(id: 't2', parcels: const [ParcelSize.s]),
      ],
    );

    expect(find.text('Заказ №1231'), findsNWidgets(2));
    expect(find.text('Улица Солнечная, дом 12'), findsNWidgets(2));
    expect(find.text('Прибытие ~15:00'), findsOneWidget);
    expect(find.text('1 место'), findsNWidgets(2));
    expect(find.text('С животными'), findsOneWidget);
    expect(find.text('Дет. кресло'), findsOneWidget);
    expect(find.text('Посылка S'), findsOneWidget);
    expect(find.text('3 отклика'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget, reason: 'no avatars yet');
    expect(find.text('16 мая, 12:00–15:00'), findsOneWidget);
    expect(find.text('16 мая, 12:00'), findsOneWidget);
    expect(find.text(formatRubles(600)), findsNWidgets(2));
  });

  testWidgets('tabs load their trips; finished ones carry a pill', (
    tester,
  ) async {
    final asked = <DriverTripsTab>[];
    await _pump(tester, (tab) async {
      asked.add(tab);
      return tab == DriverTripsTab.active
          ? [_trip(status: TripStatus.draft)]
          : [
              _trip(id: 'c', status: TripStatus.completed),
              _trip(id: 'x', status: TripStatus.cancelled),
            ];
    });

    expect(find.text('Шаблон'), findsOneWidget);
    await tester.tap(_key('trips-tab-completed'));
    await tester.pumpAndSettle();

    expect(asked, [DriverTripsTab.active, DriverTripsTab.completed]);
    expect(find.text('Завершен'), findsOneWidget);
    expect(find.text('Отменен'), findsOneWidget);
  });

  testWidgets('card and tabs call back', (tester) async {
    final opened = <String>[];
    final tabs = <DriverTab>[];
    await _pump(
      tester,
      (_) async => [_trip()],
      onOpen: (t) async => opened.add(t.id),
      onTab: tabs.add,
    );

    await tester.tap(_key('trip-card-t1'));
    await tester.tap(_key('nav-profile'));
    expect(opened, ['t1']);
    expect(tabs, [DriverTab.profile]);
  });

  test('labels', () {
    expect(requestsLabel(1), '1 отклик');
    expect(requestsLabel(3), '3 отклика');
    expect(requestsLabel(5), '5 откликов');
    expect(requestsLabel(21), '21 отклик');
  });

  test('trip json reads number, status and requests', () {
    final trip = DriverTrip.fromJson({
      'id': 't1',
      'number': 1042,
      'status': 'completed',
      'vehicle_type': 'car',
      'departure_at': '2026-05-16T07:00:00Z',
      'arrival_at': null,
      'booking_mode': 'instant',
      'car': {
        'brand': {'name': 'Toyota'},
        'model': {'name': 'Camry'},
        'plate': null,
      },
      'stops': [
        {'address': 'A'},
        {'address': 'B'},
      ],
      'seats_total': 3,
      'seats_available': 2,
      'full_price': {'driver_price': 600},
      'segment_prices': [],
      'extras': [],
      'parcel_prices': [],
      'requests': {
        'count': 2,
        'avatars': ['/media/avatars/a.jpg'],
      },
    }, mediaBaseUrl: 'https://api.example');

    expect(trip.number, 1042);
    expect(trip.status, TripStatus.completed);
    expect(trip.requestsCount, 2);
    expect(trip.requestAvatars, ['https://api.example/media/avatars/a.jpg']);
    expect(trip.seatsTotal, 3);
  });
}

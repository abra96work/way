import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_api_exception.dart';
import 'package:put/src/features/driver/domain/driver_trip.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/trips/driver_trip_page.dart';
import 'package:put/src/features/driver/presentation/widgets/price_summary.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

DriverTrip _trip() => DriverTrip(
  id: 't1',
  departureAt: DateTime(2026, 5, 15, 8),
  arrivalAt: DateTime(2026, 5, 15, 18),
  stops: const [
    'Улица Солнечная, дом 1',
    'Улица Ленина, дом 5',
    'Улица Лунная, дом 2',
  ],
  fullPrice: 1000,
  carTitle: 'Toyota Camry',
  bookingMode: BookingMode.manual,
  seatsTotal: 4,
  seatsAvailable: 2,
);

TripBooking _booking(TripBookingStatus status, {String id = 'b1'}) =>
    TripBooking(
      id: id,
      passenger: const TripPerson(
        id: 'p',
        firstName: 'Виктор',
        lastName: 'Орлов',
        rating: 4.5,
        reviewsCount: 2,
      ),
      status: status,
      seats: 2,
      boardAddress: 'Улица Ленина, дом 5',
      alightAddress: 'Улица Лунная, дом 2',
      driverPrice: 500,
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<TripBooking> Function() bookings,
  Future<void> Function(String)? confirm,
  Future<void> Function(String)? reject,
  String? openBookingId,
  Future<void> Function(TripBooking)? onOpenBooking,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: DriverTripPage(
        load: () async => (trip: _trip(), bookings: bookings()),
        loadCancelPreview: (_) async => const CancelPreview(isViolation: false),
        cancelTrip: (_) async {},
        deleteDraft: (_) async {},
        confirmBooking: confirm ?? (_) async {},
        rejectBooking: reject ?? (_) async {},
        openBookingId: openBookingId,
        onOpenBooking: onOpenBooking,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a pending request opens "Отклик"; confirming comes back', (
    tester,
  ) async {
    var status = TripBookingStatus.pending;
    final confirmed = <String>[];
    await _pump(
      tester,
      bookings: () => [_booking(status)],
      confirm: (id) async {
        confirmed.add(id);
        status = TripBookingStatus.awaitingPayment;
      },
    );

    expect(find.text('Подтвердите бронь'), findsOneWidget);
    await tester.tap(_key('trip-booking-b1'));
    await tester.pumpAndSettle();

    // The request: whole route, the passenger's part, who and how many.
    expect(find.text('Маршрут поездки'), findsOneWidget);
    expect(find.text('Маршрут пассажира'), findsOneWidget);
    expect(find.text('Точка посадки'), findsOneWidget);
    expect(find.text('Точка высадки'), findsOneWidget);
    expect(
      tester.widget<Text>(_key('trip-driver-gets')).data,
      formatRubles(500),
      reason: "the booking's own price",
    );
    expect(tester.widget<Text>(_key('request-what')).data, '2 места');

    await tester.tap(_key('request-confirm'));
    await tester.pumpAndSettle();

    expect(confirmed, ['b1']);
    expect(find.text('Бронь подтверждена'), findsOneWidget);
    expect(find.text('Ожидает оплаты'), findsOneWidget);
  });

  testWidgets('rejecting removes the passenger from the list', (tester) async {
    var rejected = false;
    await _pump(
      tester,
      bookings: () => [
        if (!rejected) _booking(TripBookingStatus.pending),
        _booking(TripBookingStatus.awaitingPayment, id: 'b2'),
      ],
      reject: (_) async => rejected = true,
    );

    await tester.tap(_key('trip-booking-b1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('request-reject'));
    await tester.pumpAndSettle();

    expect(find.text('Бронь отклонена'), findsOneWidget);
    expect(_key('trip-booking-b1'), findsNothing);
    expect(find.text('Ожидает оплаты'), findsOneWidget);
  });

  testWidgets('"Перейти к отклику" opens the request directly', (tester) async {
    await _pump(
      tester,
      bookings: () => [_booking(TripBookingStatus.pending)],
      openBookingId: 'b1',
    );

    expect(find.text('Маршрут пассажира'), findsOneWidget);
    expect(_key('request-confirm'), findsOneWidget);
  });

  testWidgets('a failed decision stays on the request', (tester) async {
    await _pump(
      tester,
      bookings: () => [_booking(TripBookingStatus.pending)],
      confirm: (_) async =>
          throw const DriverApiException('Свободных мест на этом участке: 0'),
    );

    await tester.tap(_key('trip-booking-b1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('request-confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Свободных мест на этом участке: 0'), findsOneWidget);
    expect(_key('request-confirm'), findsOneWidget);
  });

  test('booking json carries the passenger route and price', () {
    final b = TripBooking.fromJson({
      'id': 'b',
      'status': 'pending',
      'seats': 2,
      'passenger': {'id': 'p', 'first_name': 'Анна'},
      'board': {'position': 1, 'address': 'Улица Ленина, дом 5'},
      'alight': {'position': 2, 'address': 'Улица Лунная, дом 2'},
      'price': {'driver_price': 500, 'commission': 50, 'passenger_price': 550},
    });

    expect(b.boardAddress, 'Улица Ленина, дом 5');
    expect(b.alightAddress, 'Улица Лунная, дом 2');
    expect(b.driverPrice, 500);
  });

  testWidgets('the passenger block opens their profile', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      bookings: () => [_booking(TripBookingStatus.pending)],
      onOpenBooking: (b) async => opened.add(b.id),
    );

    await tester.tap(_key('trip-booking-b1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('request-passenger'));
    await tester.pumpAndSettle();
    expect(opened, ['b1']);
  });
}

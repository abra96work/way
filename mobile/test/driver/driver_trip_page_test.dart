import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_api_exception.dart';
import 'package:put/src/features/driver/domain/driver_trip.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/trips/driver_trip_page.dart';
import 'package:put/src/features/driver/presentation/widgets/price_summary.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _driver = TripPerson(
  id: 'd',
  firstName: 'Виктор',
  lastName: 'Орлов',
  rating: 4.5,
  reviewsCount: 3,
  completedTrips: 127,
);

DriverTrip _trip({
  TripStatus status = TripStatus.published,
  bool editable = true,
  bool accepting = true,
  int available = 10,
}) => DriverTrip(
  id: 't1',
  status: status,
  isEditable: editable,
  acceptsBookings: accepting,
  departureAt: DateTime(2026, 5, 15, 8),
  arrivalAt: DateTime(2026, 5, 15, 18),
  stops: const [
    'Улица Солнечная, дом 1',
    'Улица Ленина, дом 5',
    'Улица Пушкина, дом 10',
    'Улица Лунная, дом 2',
  ],
  segmentPrices: const {(0, 1): 200, (1, 2): 200, (2, 3): 200},
  fullPrice: 500,
  carTitle: 'Solaris StarLiner',
  carPlate: '7841НХ-7',
  bookingMode: BookingMode.manual,
  seatsTotal: 24,
  seatsAvailable: available,
  extras: const {TripExtraKind.luggage: 150, TripExtraKind.pets: 150},
  parcelSizes: const [ParcelSize.s, ParcelSize.m],
  driver: _driver,
);

const _booking = TripBooking(
  id: 'b1',
  passenger: TripPerson(id: 'p', firstName: 'Мария', lastName: 'Ким'),
  status: TripBookingStatus.pending,
  seats: 2,
);

Future<void> _pump(
  WidgetTester tester, {
  DriverTrip? trip,
  List<TripBooking> bookings = const [],
  CancelPreview preview = const CancelPreview(isViolation: false),
  Future<void> Function(String)? cancel,
  Future<void> Function(String)? delete,
  ValueChanged<DriverTrip>? onEdit,
  Future<void> Function(String, int)? changeSeats,
  Future<void> Function(String, bool)? setAccepting,
  Future<TripWithBookings> Function()? load,
  ValueChanged<DriverTrip>? onTransfer,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DriverTripPage(
                load:
                    load ??
                    () async => (trip: trip ?? _trip(), bookings: bookings),
                loadCancelPreview: (_) async => preview,
                cancelTrip: cancel ?? (_) async {},
                deleteDraft: delete ?? (_) async {},
                onEdit: onEdit,
                changeSeats: changeSeats,
                setAcceptingBookings: setAccepting,
                onTransferPassengers: onTransfer,
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows route, prices, seats, extras and the driver', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Поездка'), findsOneWidget);
    expect(find.text('Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('2 остановки'), findsOneWidget);
    expect(find.text('Улица Ленина, дом 5'), findsNothing);
    await tester.tap(_key('trip-stops-toggle'));
    await tester.pump();
    expect(find.text('Улица Ленина, дом 5'), findsOneWidget);

    // Commission 10 % on top: 500 + 50 = 550.
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: _key('trip-price'),
              matching: find.text(formatRubles(550)),
            ),
          )
          .data,
      formatRubles(550),
    );
    expect(find.text(formatRubles(50)), findsOneWidget);
    expect(
      tester.widget<Text>(_key('trip-driver-gets')).data,
      formatRubles(500),
    );
    expect(find.text('15 мая, 08:00'), findsOneWidget);
    // 24 seats, 10 free → 14 taken.
    expect(find.text('14 из 24'), findsOneWidget);
    expect(find.text('Прибытие ~18:00'), findsOneWidget);
    expect(find.text('С багажом'), findsOneWidget);
    expect(find.text('С животными'), findsOneWidget);
    expect(find.text('S, M'), findsOneWidget);
    expect(find.text('Пассажиры'), findsNothing);
    expect(find.text('Виктор О.'), findsOneWidget);
    expect(find.text('· 127 поездок'), findsOneWidget);
    expect(find.text('7841НХ-7'), findsOneWidget);
    expect(_key('trip-segment-0'), findsOneWidget);
    expect(find.text('Отменить поездку'), findsOneWidget);
  });

  testWidgets('lists active passengers, hides cancelled ones', (tester) async {
    await _pump(
      tester,
      bookings: const [
        _booking,
        TripBooking(
          id: 'b2',
          passenger: TripPerson(id: 'q', firstName: 'Олег'),
          status: TripBookingStatus.cancelled,
        ),
      ],
    );

    expect(find.text('Пассажиры'), findsOneWidget);
    expect(find.text('Мария К.'), findsOneWidget);
    expect(find.text('Подтвердите бронь'), findsOneWidget);
    expect(find.text('· нет отзывов'), findsOneWidget);
    expect(find.text('Олег'), findsNothing);
  });

  testWidgets('cancel with registered passengers warns, then cancels', (
    tester,
  ) async {
    final cancelled = <String>[];
    await _pump(
      tester,
      preview: const CancelPreview(
        isViolation: true,
        warning: 'Отмена нарушает правила сообщества',
        blocksAccount: true,
      ),
      cancel: (id) async => cancelled.add(id),
    );

    await tester.tap(_key('trip-cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Отмена нарушает правила сообщества'), findsOneWidget);
    expect(_key('cancel-blocks-account'), findsOneWidget);

    await tester.tap(_key('confirm-destructive'));
    await tester.pumpAndSettle();
    expect(cancelled, ['t1']);
    expect(find.text('open'), findsOneWidget, reason: 'page closed');
  });

  testWidgets('cancel error stays on the page', (tester) async {
    await _pump(
      tester,
      cancel: (_) async =>
          throw const DriverApiException('Поездка уже отправилась'),
    );

    await tester.tap(_key('trip-cancel'));
    await tester.pumpAndSettle();
    await tester.tap(_key('confirm-destructive'));
    await tester.pumpAndSettle();

    expect(find.text('Поездка уже отправилась'), findsOneWidget);
    expect(find.text('Поездка'), findsOneWidget);
  });

  testWidgets('draft offers delete; finished trips have no action', (
    tester,
  ) async {
    final deleted = <String>[];
    await _pump(
      tester,
      trip: _trip(status: TripStatus.draft),
      delete: (id) async => deleted.add(id),
    );
    expect(find.text('Удалить шаблон'), findsOneWidget);
    await tester.tap(_key('trip-cancel'));
    await tester.pumpAndSettle();
    await tester.tap(_key('confirm-destructive'));
    await tester.pumpAndSettle();
    expect(deleted, ['t1']);

    await _pump(
      tester,
      trip: _trip(status: TripStatus.completed, editable: false),
    );
    expect(_key('trip-cancel'), findsNothing);
    expect(_key('trip-menu'), findsNothing);
  });

  testWidgets('"Редактировать" in the menu', (tester) async {
    final edited = <String>[];
    await _pump(tester, onEdit: (t) => edited.add(t.id));

    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    expect(edited, ['t1']);
  });

  test('labels and parsing', () {
    expect(stopsLabel(1), '1 остановка');
    expect(stopsLabel(2), '2 остановки');
    expect(stopsLabel(5), '5 остановок');
    expect(_driver.shortName, 'Виктор О.');
    expect(_driver.ratingLabel, '4,5');

    final b = TripBooking.fromJson({
      'id': 'b',
      'status': 'awaiting_payment',
      'seats': 1,
      'parcel_size': 'M',
      'passenger': {
        'id': 'p',
        'first_name': 'Анна',
        'last_name': null,
        'avatar_url': '/media/a.jpg',
        'rating': 5.0,
        'reviews_count': 0,
        'completed_trips': 0,
      },
    }, mediaBaseUrl: 'https://api.example');
    expect(b.status, TripBookingStatus.awaitingPayment);
    expect(b.parcelSize, ParcelSize.m);
    expect(b.passenger.avatarUrl, 'https://api.example/media/a.jpg');
    expect(b.passenger.shortName, 'Анна');
  });

  testWidgets('with passengers: menu, locked edit, seats, closing booking', (
    tester,
  ) async {
    final seatsCalls = <int>[];
    final accepting = <bool>[];
    final transfers = <String>[];
    var current = _trip(editable: false, available: 14);
    await _pump(
      tester,
      load: () async => (trip: current, bookings: const [_booking]),
      onEdit: (_) => fail('editing is locked'),
      changeSeats: (_, n) async => seatsCalls.add(n),
      onTransfer: (t) => transfers.add(t.id),
      setAccepting: (_, value) async {
        accepting.add(value);
        current = _trip(editable: false, available: 14, accepting: value);
      },
    );

    // Menu as in the design.
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить количество мест'), findsOneWidget);
    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Передать пассажиров'), findsOneWidget);
    expect(find.text('Завершить приём пассажиров'), findsOneWidget);
    await tester.tap(find.text('Передать пассажиров'));
    await tester.pumpAndSettle();
    expect(transfers, ['t1']);

    // "Редактирование недоступно" sheet.
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    expect(find.text('Редактирование недоступно'), findsOneWidget);
    expect(
      find.text(
        'К поездке уже присоединились пассажиры. Маршрут, время и '
        'стоимость изменить нельзя',
      ),
      findsOneWidget,
    );
    await tester.tap(_key('edit-locked-ok'));
    await tester.pumpAndSettle();
    expect(find.text('Редактирование недоступно'), findsNothing);

    // Seats: "Сохранить" is off until the number changes.
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить количество мест'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_key('seats-value')).data, '24');
    expect(tester.widget<FilledButton>(_key('seats-save')).onPressed, isNull);
    await tester.tap(_key('seats-minus'));
    await tester.pump();
    expect(tester.widget<Text>(_key('seats-value')).data, '23');
    await tester.tap(_key('seats-save'));
    await tester.pumpAndSettle();
    expect(seatsCalls, [23]);
    expect(find.text('Изменения сохранены'), findsOneWidget);

    // Stop taking passengers, then the banner and "Возобновить".
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить приём пассажиров'));
    await tester.pumpAndSettle();
    await tester.tap(_key('confirm-destructive'));
    await tester.pumpAndSettle();
    expect(accepting, [false]);
    expect(_key('trip-booking-closed'), findsOneWidget);
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    expect(find.text('Возобновить приём пассажиров'), findsOneWidget);
  });

  testWidgets('seats cannot go below the booked ones', (tester) async {
    await _pump(
      tester,
      trip: _trip(available: 0),
      bookings: const [_booking],
      changeSeats: (_, _) async {},
    );
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить количество мест'));
    await tester.pumpAndSettle();

    // All 24 taken: "−" is off, as in the design.
    expect(tester.widget<InkWell>(_key('seats-minus')).onTap, isNull);
    expect(find.text('24 из 24'), findsOneWidget);
  });

  testWidgets('seats sheet without bookings', (tester) async {
    await _pump(
      tester,
      trip: _trip(available: 24),
      changeSeats: (_, _) async {},
    );
    await tester.tap(_key('trip-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить количество мест'));
    await tester.pumpAndSettle();

    // Nobody booked: free to go down (24 is already the limit here).
    expect(tester.widget<InkWell>(_key('seats-minus')).onTap, isNotNull);
    expect(tester.widget<InkWell>(_key('seats-plus')).onTap, isNull);
  });
}

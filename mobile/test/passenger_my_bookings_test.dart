import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/trips/domain/passenger_booking.dart';
import 'package:put/src/features/trips/presentation/passenger_booking_cancelled_page.dart';
import 'package:put/src/features/trips/presentation/passenger_booking_detail_page.dart';
import 'package:put/src/features/trips/presentation/passenger_booking_dialogs.dart';
import 'package:put/src/features/trips/presentation/passenger_my_bookings_page.dart';

void main() {
  test('booking details parse passenger API response and UTC time', () {
    final booking = PassengerBooking.fromJson(_bookingJson());

    expect(booking.id, 'booking-1');
    expect(booking.departureAt, DateTime.parse('2026-05-15T05:00:00Z'));
    expect(booking.boardAddress, 'Улица Солнечная, дом 1');
    expect(booking.alightAddress, 'Улица Лунная, дом 2');
    expect(booking.driverName, 'Виктор О.');
    expect(booking.carName, 'Solaris StarLiner');
    expect(booking.extras, ['pets', 'child_seat']);
  });

  testWidgets('my bookings filters created and active states', (tester) async {
    _setViewport(tester);
    final pending = PassengerBooking.fromJson(_bookingJson(status: 'pending'));
    final paid = PassengerBooking.fromJson(
      _bookingJson(id: 'booking-2', status: 'paid'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerMyBookingsPage(
          loadBookings: () async => [pending, paid],
          onBookingPressed: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('passenger-booking-booking-1')), findsOne);
    expect(find.byKey(const ValueKey('passenger-booking-booking-2')), findsOne);

    await tester.tap(
      find.byKey(const ValueKey('passenger-bookings-tab-created')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('passenger-booking-booking-1')), findsOne);
    expect(
      find.byKey(const ValueKey('passenger-booking-booking-2')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('passenger-bookings-tab-active')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('passenger-booking-booking-1')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('passenger-booking-booking-2')), findsOne);
  });

  testWidgets('my bookings has a cancelled filter', (tester) async {
    _setViewport(tester);
    final paid = PassengerBooking.fromJson(_bookingJson(status: 'paid'));
    final cancelled = PassengerBooking.fromJson(
      _bookingJson(id: 'booking-cancelled', status: 'cancelled'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerMyBookingsPage(
          loadBookings: () async => [paid, cancelled],
          onBookingPressed: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(-260, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('passenger-bookings-tab-cancelled')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('passenger-booking-booking-cancelled')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('passenger-booking-booking-1')),
      findsNothing,
    );
  });

  testWidgets('booking details show route, price and cancellation', (
    tester,
  ) async {
    _setViewport(tester);
    var cancelled = false;
    final booking = PassengerBooking.fromJson(_bookingJson(status: 'paid'));

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerBookingDetailPage(
          loadBooking: () async => booking,
          onBack: () {},
          onCancel: (_) async => cancelled = true,
          onPay: (_) async {},
          onMessageDriver: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('Улица Лунная, дом 2'), findsOneWidget);
    expect(find.text('1 320 ₽'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('passenger-booking-cancel')));
    await tester.pump();
    expect(cancelled, isTrue);
  });

  testWidgets('paid cancellation shows refund details and confirmation', (
    tester,
  ) async {
    _setViewport(tester);
    var confirmed = false;
    final booking = PassengerBooking.fromJson(_bookingJson(status: 'paid'));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBookingCancellationDialog(
              context,
              preview: const PassengerCancellationInfo(
                isViolation: true,
                violationsLastPeriod: 0,
                blocksAccount: false,
              ),
              booking: booking,
              onConfirm: () async => confirmed = true,
            ),
            child: const Text('cancel'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Возврат на карту'), findsOneWidget);
    expect(find.text('120 ₽'), findsOneWidget);
    expect(find.text('до 3 дней'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Да, отменить и вернуть деньги'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('booking-cancellation-confirm')),
    );
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('cancelled booking uses supplied success illustration', (
    tester,
  ) async {
    _setViewport(tester);
    final booking = PassengerBooking.fromJson(
      _bookingJson(status: 'cancelled', refunded: true),
    );

    await tester.pumpWidget(
      MaterialApp(home: PassengerBookingCancelledPage(booking: booking)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Бронь отменена'), findsOneWidget);
    expect(find.textContaining('120 ₽'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('passenger-cancelled-success-check')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('passenger-cancelled-home')),
      findsOneWidget,
    );
  });
}

Map<String, dynamic> _bookingJson({
  String id = 'booking-1',
  String status = 'awaiting_payment',
  bool refunded = false,
}) => <String, dynamic>{
  'id': id,
  'status': status,
  'kind': 'seat',
  'trip': <String, dynamic>{
    'id': 'trip-1',
    'departure_at': '2026-05-15T05:00:00Z',
    'driver': <String, dynamic>{
      'first_name': 'Виктор',
      'last_name': 'Орлов',
      'rating': 4.5,
      'completed_trips': 127,
    },
    'car': <String, dynamic>{
      'brand': 'Solaris',
      'model': 'StarLiner',
      'plate': '7841НХ-7',
    },
  },
  'board': <String, dynamic>{
    'address': 'Улица Солнечная, дом 1',
    'position': 0,
  },
  'alight': <String, dynamic>{'address': 'Улица Лунная, дом 2', 'position': 3},
  'seats': 2,
  'extras': <Map<String, dynamic>>[
    {'kind': 'pets'},
    {'kind': 'child_seat'},
  ],
  'price': <String, dynamic>{'passenger_price': 1320},
  'payment': <String, dynamic>{
    'pay_online': 120,
    'pay_to_driver': 1200,
    'is_refunded': refunded,
  },
  'can_pay': status == 'awaiting_payment',
  'can_cancel': status != 'completed',
};

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

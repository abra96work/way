import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_trip.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/trips/passenger_profile_page.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _passenger = TripPerson(
  id: 'p',
  firstName: 'Виктор',
  lastName: 'Орлов',
  rating: 4.8,
  reviewsCount: 12,
  completedTrips: 120,
);

TripBooking _booking(TripBookingStatus status, {String? phone}) => TripBooking(
  id: 'b1',
  passenger: _passenger,
  status: status,
  seats: 2,
  phone: phone,
  boardAddress: 'Улица Солнечная, дом 1',
  alightAddress: 'Улица Лунная, дом 2',
);

Future<void> _pump(
  WidgetTester tester,
  TripBooking booking, {
  VoidCallback? onChat,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TripPassengerProfilePage(booking: booking, onChat: onChat ?? () {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('before acceptance: name, rating and "Написать"', (tester) async {
    var chats = 0;
    await _pump(
      tester,
      _booking(TripBookingStatus.pending),
      onChat: () => chats++,
    );

    expect(find.text('Профиль пассажира'), findsOneWidget);
    expect(find.text('Виктор О.'), findsOneWidget);
    expect(find.text('4,8'), findsOneWidget);
    expect(find.text('· 120 поездок'), findsOneWidget);
    expect(_key('passenger-phone'), findsNothing);
    expect(_key('passenger-route'), findsNothing);

    await tester.tap(_key('passenger-chat'));
    expect(chats, 1);
  });

  testWidgets('after acceptance: phone and the passenger route', (
    tester,
  ) async {
    await _pump(
      tester,
      _booking(TripBookingStatus.awaitingPayment, phone: '+79001110001'),
    );

    expect(find.text('+7 900 111 00 01'), findsOneWidget);
    expect(find.text('Маршрут пассажира'), findsOneWidget);
    expect(find.text('Точка посадки'), findsOneWidget);
    expect(find.text('Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('Улица Лунная, дом 2'), findsOneWidget);
    expect(find.text('Написать'), findsOneWidget);
  });

  test('phone format, accepted statuses and booking label', () {
    expect(formatPhone('+79001110001'), '+7 900 111 00 01');
    expect(formatPhone('12345'), '12345');
    expect(
      TripPassengerProfilePage.isAccepted(TripBookingStatus.pending),
      isFalse,
    );
    expect(TripPassengerProfilePage.isAccepted(TripBookingStatus.paid), isTrue);
    expect(_booking(TripBookingStatus.paid).what, '2 места');
    expect(
      const TripBooking(
        id: 'x',
        passenger: _passenger,
        status: TripBookingStatus.paid,
        parcelSize: ParcelSize.l,
      ).what,
      'Посылка L',
    );
  });
}

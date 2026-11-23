import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_api_exception.dart';
import 'package:put/src/features/driver/domain/driver_trip.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/publish_confirm_sheet.dart';
import 'package:put/src/features/driver/presentation/create_trip/reverse_trip_page.dart';
import 'package:put/src/features/driver/presentation/create_trip/trip_published_page.dart';
import 'package:put/src/features/driver/presentation/widgets/price_summary.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

DateTime _now() => DateTime(2026, 11, 24, 10, 10);

Map<String, dynamic> _price(int p) => {
  'driver_price': p,
  'commission': (p * 10 + 50) ~/ 100,
  'passenger_price': p + (p * 10 + 50) ~/ 100,
};

Map<String, dynamic> _tripJson({String? returnOf}) => {
  'id': 't1',
  'status': 'published',
  'vehicle_type': 'car',
  'departure_at': DateTime(2026, 11, 25, 9).toUtc().toIso8601String(),
  'arrival_at': DateTime(2026, 11, 25, 12).toUtc().toIso8601String(),
  'booking_mode': 'manual',
  'car': {
    'id': 'c1',
    'brand': {'id': 1, 'name': 'Toyota'},
    'model': {'id': 2, 'name': 'Camry'},
    'plate': '7841НХ-7',
  },
  'stops': [
    {'position': 0, 'address': 'Победителей 1, Минск'},
    {'position': 1, 'address': 'Комсомольская 13, Жодино'},
    {'position': 2, 'address': 'Рынок местный, Могилев'},
  ],
  'full_price': _price(1200),
  'min_price': _price(150),
  'segment_prices': [
    {'from_position': 0, 'to_position': 1, 'price': _price(500)},
    {'from_position': 1, 'to_position': 2, 'price': _price(800)},
  ],
  'extras': [
    {'kind': 'child_seat', 'price': _price(150)},
    {'kind': 'pets', 'price': _price(150)},
  ],
  'parcel_prices': [
    {'size': 'S', 'price': _price(150)},
  ],
  'return_of_trip_id': returnOf,
};

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(375, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  test('trip json is parsed and mirrored for the way back', () {
    final trip = DriverTrip.fromJson(_tripJson());

    expect(trip.stops.first, 'Победителей 1, Минск');
    expect(trip.fullPrice, 1200);
    expect(trip.carTitle, 'Toyota Camry');
    expect(trip.departureAt, DateTime(2026, 11, 25, 9));
    expect(trip.extras, {
      TripExtraKind.childSeat: 150,
      TripExtraKind.pets: 150,
    });
    expect(trip.parcelSizes, [ParcelSize.s]);
    expect(trip.isReturnTrip, isFalse);

    expect(trip.reversedStops.first, 'Рынок местный, Могилев');
    // Могилев → Жодино is the original Жодино → Могилев.
    expect(trip.reversedSegmentPrice(0, 1), 800);
    expect(trip.reversedSegmentPrice(1, 2), 500);

    final preview = TripPreview.reverseOf(trip, DateTime(2026, 11, 25, 18));
    expect(preview.segmentPrices, [800, 500]);
    expect(preview.carTitle, 'Toyota Camry, 7841НХ-7');
    expect(preview.extrasPrice, 300);
  });

  testWidgets('confirm sheet lists the trip and can show stop prices', (
    tester,
  ) async {
    final trip = DriverTrip.fromJson(_tripJson());
    bool? result;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showPublishConfirmSheet(
            context,
            TripPreview.reverseOf(trip, DateTime(2026, 11, 25, 18)),
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Опубликовать поездку?'), findsOneWidget);
    expect(find.text('Рынок местный, Могилев'), findsOneWidget);
    expect(find.text('25.11.2026, 18:00'), findsOneWidget);
    expect(find.text('Toyota Camry, 7841НХ-7'), findsOneWidget);
    expect(find.text('Детское кресло, Животные'), findsOneWidget);
    expect(find.text('Стандартное'), findsOneWidget);
    expect(_key('confirm-segment-0'), findsNothing);

    await tester.ensureVisible(_key('confirm-segments-toggle'));
    await tester.pumpAndSettle();
    await tester.tap(_key('confirm-segments-toggle'));
    await tester.pump();
    expect(_key('confirm-segment-0'), findsOneWidget);
    expect(find.text(formatRubles(800)), findsOneWidget);

    await tester.tap(_key('confirm-cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  group('reverse trip page', () {
    testWidgets('mirrors the route and publishes after confirmation', (
      tester,
    ) async {
      DateTime? departure;
      DateTime? arrival;
      bool? published;
      await _pump(
        tester,
        ReverseTripPage(
          source: DriverTrip.fromJson(_tripJson()),
          clock: _now,
          onSubmit: (d, a, {required publish}) async {
            departure = d;
            arrival = a;
            published = publish;
          },
        ),
      );

      expect(find.text('Обратное направление'), findsOneWidget);
      expect(find.textContaining('Шаг'), findsNothing);
      expect(find.text('Вы получите'), findsOneWidget);
      final first = tester.widget<Text>(
        find.descendant(
          of: _key('reverse-stop-0'),
          matching: find.text('Рынок местный, Могилев'),
        ),
      );
      expect(first.data, 'Рынок местный, Могилев');
      expect(
        tester.widget<FilledButton>(_key('new-trip-next')).onPressed,
        isNull,
      );

      await tester.tap(_key('reverse-date'));
      await tester.pumpAndSettle();
      await tester.tap(_key('calendar-day-11-25'));
      await tester.pump();
      await tester.tap(_key('sheet-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(_key('reverse-time'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sheet-confirm')); // next slot: 10:30
      await tester.pumpAndSettle();

      await tester.tap(_key('new-trip-next'));
      await tester.pumpAndSettle();
      expect(find.text('Опубликовать поездку?'), findsOneWidget);
      await tester.tap(_key('confirm-publish'));
      await tester.pumpAndSettle();

      expect(departure, DateTime(2026, 11, 25, 10, 30));
      expect(arrival, isNull);
      expect(published, isTrue);
    });

    testWidgets('daily limit offers to save the way back as a template', (
      tester,
    ) async {
      final calls = <bool>[];
      await _pump(
        tester,
        ReverseTripPage(
          source: DriverTrip.fromJson(_tripJson()),
          clock: _now,
          onSubmit: (d, a, {required publish}) async {
            calls.add(publish);
            if (publish) {
              throw const DriverApiException(
                'limit',
                code: 'daily_trip_limit',
                details: {
                  'date': '2026-11-25',
                  'published': 2,
                  'there': {'used': 1, 'limit': 1},
                  'back': {'used': 1, 'limit': 1},
                },
              );
            }
          },
        ),
      );

      await tester.tap(_key('reverse-date'));
      await tester.pumpAndSettle();
      await tester.tap(_key('calendar-day-11-25'));
      await tester.pump();
      await tester.tap(_key('sheet-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(_key('reverse-time'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sheet-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(_key('new-trip-next'));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-publish'));
      await tester.pumpAndSettle();

      expect(find.text('Достигнут лимит на этот день'), findsOneWidget);
      await tester.tap(_key('limit-save-template'));
      await tester.pumpAndSettle();
      expect(calls, [true, false]);
    });
  });

  group('published page', () {
    testWidgets('shows limits and offers the way back', (tester) async {
      DateTime? asked;
      var reverse = 0;
      await _pump(
        tester,
        TripPublishedPage(
          trip: DriverTrip.fromJson(_tripJson()),
          clock: () => DateTime(2026, 11, 25, 7),
          loadLimits: (day) async {
            asked = day;
            return PublishLimits(
              date: DateTime(2026, 11, 25),
              dayUsed: 2,
              dayLimit: 2,
              weekUsed: 3,
              weekLimit: 10,
            );
          },
          onMyTrips: () {},
          onCreateReverse: () => reverse++,
        ),
      );

      expect(find.text('Заказ опубликован!'), findsOneWidget);
      expect(asked, DateTime(2026, 11, 25, 9));
      expect(find.text('Сегодня'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('3 / 10'), findsOneWidget);

      await tester.tap(_key('published-reverse'));
      expect(reverse, 1);
    });

    testWidgets('a way-back trip has no reverse button; limits may fail', (
      tester,
    ) async {
      await _pump(
        tester,
        TripPublishedPage(
          trip: DriverTrip.fromJson(_tripJson(returnOf: 't0')),
          loadLimits: (_) async => throw Exception('offline'),
          onMyTrips: () {},
        ),
      );

      expect(find.text('Заказ опубликован!'), findsOneWidget);
      expect(_key('published-reverse'), findsNothing);
      expect(find.text('Лимит публикаций'), findsNothing);
    });
  });
}

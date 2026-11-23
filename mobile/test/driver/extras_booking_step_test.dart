import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_api_exception.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/booking_step_page.dart';
import 'package:put/src/features/driver/presentation/create_trip/daily_limit_dialog.dart';
import 'package:put/src/features/driver/presentation/create_trip/extras_step_page.dart';
import 'package:put/src/features/driver/presentation/widgets/price_summary.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

TripDraft _draft() {
  final draft = TripDraft();
  draft
    ..updateStop(
      0,
      text: 'Центр, Минск',
      city: const City(id: 1, name: 'Минск'),
    )
    ..updateStop(
      1,
      text: 'Рынок, Могилев',
      city: const City(id: 2, name: 'Могилев'),
    )
    ..departureDate = DateTime(2026, 11, 25)
    ..departureTime = const TimeOfDay(hour: 9, minute: 0)
    ..seats = 3
    ..fullPrice = 1000
    ..carId = 'c1';
  return draft;
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(375, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  group('step 5: extras', () {
    testWidgets('toggles extras and shows their price', (tester) async {
      final draft = _draft();
      var next = 0;
      await _pump(tester, ExtrasStepPage(draft: draft, onNext: () => next++));

      expect(find.text('Шаг 5 из 6'), findsOneWidget);
      expect(find.text('до ${formatRubles(350)}'), findsOneWidget);
      expect(find.text('+${formatRubles(150)}'), findsNothing);

      await tester.tap(_key('extra-child_seat'));
      await tester.tap(_key('extra-pets'));
      await tester.pump();
      expect(draft.extras, {TripExtraKind.childSeat, TripExtraKind.pets});
      expect(find.text('+${formatRubles(150)}'), findsNWidgets(2));

      await tester.tap(_key('extra-pets'));
      await tester.pump();
      expect(draft.extras, {TripExtraKind.childSeat});

      // Nothing is required here.
      await tester.tap(_key('new-trip-next'));
      expect(next, 1);
    });

    testWidgets('parcel sheet: choose, add, cancel', (tester) async {
      final draft = _draft();
      await _pump(tester, ExtrasStepPage(draft: draft, onNext: () {}));

      await tester.tap(_key('extra-parcel'));
      await tester.pumpAndSettle();
      expect(find.text('Маленькая'), findsOneWidget);
      // Nothing chosen yet — "Добавить" is disabled.
      expect(
        tester.widget<FilledButton>(_key('parcel-save')).onPressed,
        isNull,
      );

      await tester.tap(_key('parcel-S'));
      await tester.pump();
      await tester.tap(_key('parcel-save'));
      await tester.pumpAndSettle();
      expect(draft.parcelSizes, {ParcelSize.s});
      expect(find.text(formatRubles(150)), findsOneWidget);

      // Cancel keeps what was saved.
      await tester.tap(_key('extra-parcel'));
      await tester.pumpAndSettle();
      await tester.tap(_key('parcel-L'));
      await tester.tap(_key('parcel-cancel'));
      await tester.pumpAndSettle();
      expect(draft.parcelSizes, {ParcelSize.s});

      // Unchecking everything and saving stops taking parcels.
      await tester.tap(_key('extra-parcel'));
      await tester.pumpAndSettle();
      await tester.tap(_key('parcel-S'));
      await tester.pump();
      expect(find.text('Сохранить'), findsOneWidget);
      await tester.tap(_key('parcel-save'));
      await tester.pumpAndSettle();
      expect(draft.parcelSizes, isEmpty);
    });
  });

  group('step 6: booking mode', () {
    testWidgets('publish needs a mode, template does not', (tester) async {
      final draft = _draft();
      var published = 0;
      var saved = 0;
      await _pump(
        tester,
        BookingStepPage(
          draft: draft,
          onPublish: () async => published++,
          onSaveTemplate: () async => saved++,
        ),
      );

      expect(find.text('Шаг 6 из 6'), findsOneWidget);
      final publish = _key('new-trip-next');
      expect(tester.widget<FilledButton>(publish).onPressed, isNull);

      await tester.tap(_key('new-trip-secondary'));
      await tester.pumpAndSettle();
      expect(saved, 1);

      await tester.tap(_key('booking-instant'));
      await tester.pump();
      expect(draft.bookingMode, BookingMode.instant);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-publish'));
      await tester.pumpAndSettle();
      expect(published, 1);
    });

    testWidgets('server error is shown and buttons come back', (tester) async {
      final draft = _draft()..bookingMode = BookingMode.manual;
      await _pump(
        tester,
        BookingStepPage(
          draft: draft,
          onPublish: () async => throw const DriverApiException(
            'В сутки можно опубликовать одну поездку',
          ),
          onSaveTemplate: () async {},
        ),
      );

      await tester.tap(_key('new-trip-next'));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-publish'));
      await tester.pumpAndSettle();

      expect(
        find.text('В сутки можно опубликовать одну поездку'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(_key('new-trip-next')).onPressed,
        isNotNull,
      );
    });

    testWidgets('daily limit opens the dialog and can save a template', (
      tester,
    ) async {
      final draft = _draft()..bookingMode = BookingMode.manual;
      var saved = 0;
      await _pump(
        tester,
        BookingStepPage(
          draft: draft,
          clock: () => DateTime(2026, 11, 25, 7),
          onPublish: () async => throw const DriverApiException(
            'В сутки можно опубликовать одну поездку и одну в обратном направлении',
            code: 'daily_trip_limit',
            details: {
              'date': '2026-11-25',
              'published': 2,
              'there': {'used': 1, 'limit': 1},
              'back': {'used': 1, 'limit': 1},
            },
          ),
          onSaveTemplate: () async => saved++,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('new-trip-next')));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-publish'));
      await tester.pumpAndSettle();

      expect(find.text('Достигнут лимит на сегодня'), findsOneWidget);
      expect(
        find.textContaining('Сегодня у вас уже 2 публикации'),
        findsOneWidget,
      );
      expect(find.textContaining('На легковой автомобиль'), findsOneWidget);
      expect(find.text('1/1'), findsNWidgets(2));
      // The dialog replaces the snack bar.
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.byKey(const ValueKey('limit-save-template')));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(find.byType(DailyLimitDialog), findsNothing);
    });

    testWidgets('limit on another day names the date; cancel just closes', (
      tester,
    ) async {
      final draft = _draft()
        ..vehicleType = VehicleType.bus
        ..bookingMode = BookingMode.manual;
      var saved = 0;
      await _pump(
        tester,
        BookingStepPage(
          draft: draft,
          clock: () => DateTime(2026, 11, 23, 7),
          onPublish: () async => throw const DriverApiException(
            'limit',
            code: 'daily_trip_limit',
            details: {
              'date': '2026-11-25',
              'published': 1,
              'there': {'used': 1, 'limit': 1},
              'back': {'used': 0, 'limit': 1},
            },
          ),
          onSaveTemplate: () async => saved++,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('new-trip-next')));
      await tester.pumpAndSettle();
      await tester.tap(_key('confirm-publish'));
      await tester.pumpAndSettle();

      expect(find.text('Достигнут лимит на этот день'), findsOneWidget);
      expect(
        find.textContaining('На 25.11.2026 у вас уже 1 публикация'),
        findsOneWidget,
      );
      expect(find.textContaining('На автобус'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('limit-cancel')));
      await tester.pumpAndSettle();
      expect(saved, 0);
      expect(find.byType(DailyLimitDialog), findsNothing);
    });
  });

  test('publications word declines', () {
    expect(publicationsWord(1), 'публикация');
    expect(publicationsWord(2), 'публикации');
    expect(publicationsWord(5), 'публикаций');
    expect(publicationsWord(11), 'публикаций');
    expect(publicationsWord(21), 'публикация');
  });

  test('extras, parcels and mode go into POST /trips', () {
    final draft = _draft()
      ..setExtra(TripExtraKind.luggage, true)
      ..setExtra(TripExtraKind.childSeat, true)
      ..parcelSizes = {ParcelSize.l, ParcelSize.s}
      ..bookingMode = BookingMode.instant;

    final body = draft.toCreateTripJson(publish: false);

    expect(body['booking_mode'], 'instant');
    expect(body['extras'], [
      {'kind': 'child_seat', 'price': 150},
      {'kind': 'luggage', 'price': 150},
    ]);
    expect(body['parcel_prices'], [
      {'size': 'S', 'price': 150},
      {'size': 'L', 'price': 350},
    ]);
    expect(body['publish'], isFalse);

    draft.reset();
    expect(draft.extras, isEmpty);
    expect(draft.parcelSizes, isEmpty);
    expect(draft.bookingMode, isNull);
  });
}

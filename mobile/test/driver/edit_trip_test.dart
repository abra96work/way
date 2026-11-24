import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_api_exception.dart';
import 'package:put/src/features/driver/domain/driver_trip.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/extras_step_page.dart';
import 'package:put/src/features/driver/presentation/create_trip/price_step_page.dart';
import 'package:put/src/features/driver/presentation/create_trip/route_step_page.dart';
import 'package:put/src/features/driver/presentation/widgets/trip_edit_scope.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

const _minsk = City(id: 1, name: 'Минск');
const _zhodino = City(id: 3, name: 'Жодино');
const _mogilev = City(id: 2, name: 'Могилев');

DateTime _now() => DateTime(2026, 11, 24, 10, 10);

DriverTrip _trip() => DriverTrip(
  id: 't1',
  departureAt: DateTime(2026, 11, 25, 8),
  arrivalAt: DateTime(2026, 11, 25, 12),
  stops: const [
    'Победителей 1, Минск',
    'Космонавтов 13, Жодино',
    'Рынок местный, Могилев',
  ],
  stopCities: const [_minsk, _zhodino, _mogilev],
  segmentPrices: const {(0, 1): 300, (1, 2): 400},
  fullPrice: 600,
  minPrice: 100,
  carId: 'c1',
  carTitle: 'Toyota Camry',
  bookingMode: BookingMode.instant,
  seatsTotal: 3,
  extras: const {TripExtraKind.pets: 150},
  parcelSizes: const [ParcelSize.s],
);

TripDraft _loaded() => TripDraft()..loadTrip(_trip());

Future<void> _pump(
  WidgetTester tester,
  TripDraft draft,
  Widget page, {
  Future<void> Function()? onSave,
  VoidCallback? onEditPrices,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: TripEditScope(
        canSave: () => draft.isDirty && draft.isComplete(_now()),
        onSave: onSave ?? () async {},
        onEditPrices: onEditPrices,
        child: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _route(TripDraft draft) => RouteStepPage(
  draft: draft,
  loadCities: () async => const [_minsk, _zhodino, _mogilev],
  onNext: () {},
  clock: _now,
);

void main() {
  test('loadTrip copies the trip and tracks changes', () {
    final draft = _loaded();

    expect(draft.isDirty, isFalse);
    expect(draft.isComplete(_now()), isTrue);
    expect(draft.stops.map((s) => s.city), [_minsk, _zhodino, _mogilev]);
    expect(draft.departureTime, const TimeOfDay(hour: 8, minute: 0));
    expect(draft.arrivalTime, const TimeOfDay(hour: 12, minute: 0));
    expect(draft.segmentPrice(draft.stops[0], draft.stops[1]), 300);
    expect(draft.bookingMode, BookingMode.instant);

    final body = draft.toWriteJson();
    expect(body.containsKey('publish'), isFalse);
    expect(body['car_id'], 'c1');
    expect(body['min_price'], 100);
    expect(body['booking_mode'], 'instant');
    expect(body['extras'], [
      {'kind': 'pets', 'price': 150},
    ]);

    draft.seats = 2;
    expect(draft.isDirty, isTrue);
    draft.seats = 3;
    expect(draft.isDirty, isFalse, reason: 'back to the original');
  });

  testWidgets(
    'route step: "Изменение заказа", no step counter, save on change',
    (tester) async {
      final draft = _loaded();
      var saved = 0;
      var prices = 0;
      await _pump(
        tester,
        draft,
        _route(draft),
        onSave: () async => saved++,
        onEditPrices: () => prices++,
      );

      expect(find.text('Изменение заказа'), findsOneWidget);
      expect(find.textContaining('Шаг'), findsNothing, reason: 'no counter');
      expect(find.text('Победителей 1, Минск'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(_key('edit-save')).onPressed,
        isNull,
        reason: 'nothing changed yet',
      );

      await tester.tap(_key('edit-prices'));
      expect(prices, 1);

      await tester.tap(_key('route-seats-minus'));
      await tester.pump();
      final save = tester.widget<OutlinedButton>(_key('edit-save'));
      expect(save.onPressed, isNotNull);
      await tester.tap(_key('edit-save'));
      await tester.pumpAndSettle();
      expect(saved, 1);
    },
  );

  testWidgets('prices screen has its own title and "Готово"', (tester) async {
    final draft = _loaded();
    var done = 0;
    await _pump(
      tester,
      draft,
      PriceStepPage(draft: draft, onNext: () => done++),
    );

    expect(find.text('Изменение стоимости'), findsOneWidget);
    expect(find.textContaining('Шаг'), findsNothing);
    await tester.tap(find.text('Готово'));
    expect(done, 1);
  });

  testWidgets('last step has only "Сохранить"; errors are shown', (
    tester,
  ) async {
    final draft = _loaded()..setExtra(TripExtraKind.luggage, true);
    await _pump(
      tester,
      draft,
      ExtrasStepPage(draft: draft, onNext: () {}),
      onSave: () async =>
          throw const DriverApiException('Поездку уже нельзя изменить'),
    );

    expect(find.textContaining('Шаг'), findsNothing);
    expect(find.text('Далее'), findsNothing);
    await tester.tap(_key('edit-save'));
    await tester.pumpAndSettle();
    expect(find.text('Поездку уже нельзя изменить'), findsOneWidget);
  });
}

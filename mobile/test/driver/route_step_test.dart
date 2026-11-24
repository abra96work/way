import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/route_step_page.dart';

const _ekb = City(id: 1, name: 'Екатеринбург', region: 'Свердловская область');
const _asbest = City(id: 9, name: 'Асбест', region: 'Свердловская область');
const _berez = City(id: 2, name: 'Берёзовский', region: 'Свердловская область');
const _chelyabinsk = City(
  id: 21,
  name: 'Челябинск',
  region: 'Челябинская область',
);

// Tuesday 24 November 2026, 10:10 local.
DateTime _now() => DateTime(2026, 11, 24, 10, 10);

Future<List<City>> _cities() async => const [
  _ekb,
  _berez,
  _asbest,
  _chelyabinsk,
];

Finder _key(String key) => find.byKey(ValueKey(key));

/// The text field of the route row whose stop has [id].
Finder _field(int id) => find.descendant(
  of: _key('route-point-$id'),
  matching: find.byType(TextField),
);

Future<void> _pump(
  WidgetTester tester,
  TripDraft draft, {
  VoidCallback? onNext,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: RouteStepPage(
        draft: draft,
        loadCities: _cities,
        onNext: onNext ?? () {},
        clock: _now,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton _nextButton(WidgetTester tester) =>
    tester.widget<FilledButton>(_key('new-trip-next'));

TripDraft _filledDraft() {
  final draft = TripDraft();
  draft
    ..updateStop(0, text: 'Вокзал, Екатеринбург', city: _ekb)
    ..updateStop(1, text: 'Рынок, Асбест', city: _asbest)
    ..departureDate = DateTime(2026, 11, 25)
    ..departureTime = const TimeOfDay(hour: 9, minute: 0)
    ..seats = 3;
  return draft;
}

void main() {
  testWidgets('starts empty with labels from the design', (tester) async {
    await _pump(tester, TripDraft());

    expect(find.text('Шаг 2 из 6'), findsOneWidget);
    expect(find.text('Точка посадки'), findsOneWidget);
    expect(find.text('Пункт назначения'), findsOneWidget);
    expect(find.text('Дата'), findsOneWidget);
    expect(find.text('Количество мест:'), findsOneWidget);
    expect(_nextButton(tester).onPressed, isNull);
  });

  testWidgets('typed address recognises the city after a comma', (
    tester,
  ) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.enterText(_field(0), 'Победителей 1, екатеринбург');
    await tester.pump();

    expect(draft.stops.first.city, _ekb);
    expect(draft.stops.first.text, 'Победителей 1, екатеринбург');
  });

  testWidgets('city suggestion completes the address', (tester) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.tap(_field(1));
    await tester.enterText(_field(1), 'Рынок местный, асб');
    await tester.pumpAndSettle();
    await tester.tap(_key('route-suggestion-9'));
    await tester.pumpAndSettle();

    expect(draft.stops.last.city, _asbest);
    expect(draft.stops.last.text, 'Рынок местный, Асбест');
    expect(find.text('Рынок местный, Асбест'), findsOneWidget);
  });

  testWidgets('suggestions ignore ё', (tester) async {
    await _pump(tester, TripDraft());

    await tester.tap(_field(0));
    await tester.enterText(_field(0), 'Ленина 5, березов');
    await tester.pumpAndSettle();

    expect(_key('route-suggestion-2'), findsOneWidget);
  });

  testWidgets('exact city name remains visible in suggestions', (tester) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.tap(_field(0));
    await tester.enterText(_field(0), 'Екатеринбург');
    await tester.pumpAndSettle();

    expect(draft.stops.first.city, _ekb);
    expect(_key('route-suggestion-1'), findsOneWidget);
  });

  testWidgets('address without a known city is flagged after leaving it', (
    tester,
  ) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.tap(_field(0));
    await tester.enterText(_field(0), 'Победителей 1, Минск');
    await tester.tap(_field(1));
    await tester.pumpAndSettle();

    expect(draft.stops.first.city, isNull);
    expect(find.text('Выберите город из списка'), findsOneWidget);
  });

  testWidgets('same city for start and end shows an error', (tester) async {
    final draft = TripDraft()
      ..updateStop(0, text: 'Вокзал, Екатеринбург', city: _ekb)
      ..updateStop(1, text: 'Рынок, Екатеринбург', city: _ekb);
    await _pump(tester, draft);

    expect(_key('route-same-city-error'), findsOneWidget);
  });

  testWidgets('adds a stop with a dot marker and removes it with ×', (
    tester,
  ) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.tap(_key('route-add-stop'));
    await tester.pump();
    expect(find.text('Точка посадки'), findsNWidgets(2));
    expect(draft.stops.length, 3);

    final added = draft.stops[1].id;
    await tester.tap(_key('route-clear-$added'));
    await tester.pump();
    expect(draft.stops.length, 2);
  });

  testWidgets('× on the first point clears it', (tester) async {
    final draft = TripDraft()
      ..updateStop(0, text: 'Вокзал, Екатеринбург', city: _ekb);
    await _pump(tester, draft);

    await tester.tap(_key('route-clear-${draft.stops.first.id}'));
    await tester.pump();

    expect(draft.stops.first.text, isEmpty);
    expect(draft.stops.first.city, isNull);
  });

  testWidgets('calendar offers today and the next 3 days', (tester) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.tap(_key('route-date'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать дату'), findsNWidgets(2));
    expect(find.text('Ноябрь 2026'), findsOneWidget);

    await tester.tap(_key('calendar-day-11-23'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(_key('sheet-confirm'));
    expect(confirm.onPressed, isNull, reason: 'yesterday is not allowed');

    await tester.tap(_key('calendar-day-11-28'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(_key('sheet-confirm')).onPressed,
      isNull,
      reason: '28 November is more than 3 days ahead',
    );

    await tester.tap(_key('calendar-day-11-27'));
    await tester.pump();
    await tester.tap(_key('sheet-confirm'));
    await tester.pumpAndSettle();

    expect(draft.departureDate, DateTime(2026, 11, 27));
    expect(find.text('27.11.2026'), findsOneWidget);
  });

  testWidgets('later than 3 days from now shows a hint and blocks "Далее"', (
    tester,
  ) async {
    // Now is 24.11 10:10, so 27.11 10:30 is past the 72-hour window.
    final draft = _filledDraft()
      ..departureDate = DateTime(2026, 11, 27)
      ..departureTime = const TimeOfDay(hour: 10, minute: 30);
    await _pump(tester, draft);

    expect(_key('route-too-far-error'), findsOneWidget);
    expect(_nextButton(tester).onPressed, isNull);

    draft.departureTime = const TimeOfDay(hour: 10, minute: 0);
    await tester.pump();
    expect(_key('route-too-far-error'), findsNothing);
    expect(_nextButton(tester).onPressed, isNotNull);
  });

  testWidgets('time sheet picks hours and 30-minute steps', (tester) async {
    final draft = TripDraft()..departureDate = DateTime(2026, 11, 25);
    await _pump(tester, draft);

    await tester.tap(_key('route-time'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать время'), findsNWidgets(2));
    // Starts at the next free slot after 10:10 → 10:30.
    await tester.tap(_key('sheet-confirm'));
    await tester.pumpAndSettle();

    expect(draft.departureTime, const TimeOfDay(hour: 10, minute: 30));
    expect(find.text('10:30'), findsOneWidget);
  });

  testWidgets('past departure today shows a hint and blocks "Далее"', (
    tester,
  ) async {
    final draft = _filledDraft()
      ..departureDate = DateTime(2026, 11, 24)
      ..departureTime = const TimeOfDay(hour: 8, minute: 0);
    await _pump(tester, draft);

    expect(_key('route-past-error'), findsOneWidget);
    expect(_nextButton(tester).onPressed, isNull);
  });

  testWidgets('optional arrival can be cleared', (tester) async {
    final draft = _filledDraft()
      ..arrivalTime = const TimeOfDay(hour: 11, minute: 30);
    await _pump(tester, draft);
    expect(find.text('11:30'), findsOneWidget);

    await tester.tap(_key('route-arrival'));
    await tester.pumpAndSettle();
    await tester.tap(_key('time-clear'));
    await tester.pumpAndSettle();

    expect(draft.arrivalTime, isNull);
  });

  testWidgets('seats stepper is limited by the vehicle type', (tester) async {
    final draft = TripDraft();
    await _pump(tester, draft);

    await tester.tap(_key('route-seats-minus'));
    await tester.pump();
    expect(draft.seats, 0);

    for (var i = 0; i < 10; i++) {
      await tester.tap(_key('route-seats-plus'));
      await tester.pump();
    }
    expect(draft.seats, 8);
  });

  testWidgets('filled step enables "Далее"', (tester) async {
    var nextCalls = 0;
    await _pump(tester, _filledDraft(), onNext: () => nextCalls++);

    await tester.tap(_key('new-trip-next'));

    expect(nextCalls, 1);
  });

  testWidgets('Челябинск in an intermediate stop keeps "Далее" enabled', (
    tester,
  ) async {
    final draft = _filledDraft();
    draft
      ..addStop()
      ..updateStop(1, text: 'Мира 1, Челябинск', city: _chelyabinsk);

    await _pump(tester, draft);

    expect(_nextButton(tester).onPressed, isNotNull);
  });

  test('detectCity takes the last matching part', () {
    const cities = [_ekb, _asbest, _chelyabinsk];
    expect(detectCity('Победителей 1, Асбест', cities), _asbest);
    expect(detectCity('Асбестовская ул., Екатеринбург', cities), _ekb);
    expect(detectCity('Победителей 1', cities), isNull);
    expect(detectCity('Мира 1, Челябинск', cities), _chelyabinsk);
  });

  test('arrival earlier than departure means the next day', () {
    final draft = TripDraft()
      ..departureDate = DateTime(2026, 11, 25)
      ..departureTime = const TimeOfDay(hour: 22, minute: 0)
      ..arrivalTime = const TimeOfDay(hour: 1, minute: 30);

    expect(draft.arrivalAt, DateTime(2026, 11, 26, 1, 30));
  });

  test('formats date and time like the design', () {
    expect(formatDate(DateTime(2026, 6, 4)), '04.06.2026');
    expect(formatTime(const TimeOfDay(hour: 8, minute: 0)), '8:00');
  });
}

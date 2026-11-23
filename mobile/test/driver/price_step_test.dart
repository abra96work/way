import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/pricing.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/price_step_page.dart';
import 'package:put/src/features/driver/presentation/widgets/price_summary.dart';

const _minsk = City(id: 1, name: 'Минск');
const _mogilev = City(id: 2, name: 'Могилев');

Finder _key(String key) => find.byKey(ValueKey(key));

Finder _input(String key) =>
    find.descendant(of: _key(key), matching: find.byType(EditableText));

TripDraft _draft({bool withStop = false}) {
  final draft = TripDraft();
  if (withStop) draft.addStop();
  final last = draft.stops.length - 1;
  draft
    ..updateStop(0, text: 'Победителей 1, Минск', city: _minsk)
    ..updateStop(last, text: 'Рынок местный, Могилев', city: _mogilev);
  if (withStop) {
    draft.updateStop(1, text: 'Комсомонавтов 13, Минск', city: _minsk);
  }
  return draft;
}

Future<void> _pump(
  WidgetTester tester,
  TripDraft draft, {
  VoidCallback? onNext,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PriceStepPage(draft: draft, onNext: onNext ?? () {}),
    ),
  );
}

FilledButton _next(WidgetTester tester) =>
    tester.widget<FilledButton>(_key('new-trip-next'));

void main() {
  testWidgets('without stops shows the whole route and boarding only', (
    tester,
  ) async {
    await _pump(tester, _draft());

    expect(find.text('Шаг 3 из 6'), findsOneWidget);
    expect(find.text('Весь маршрут'), findsOneWidget);
    expect(find.text('Между остановками'), findsNothing);
    expect(find.text('Стоимость посадки'), findsOneWidget);
    expect(
      find.text('Победителей 1, Минск', findRichText: true),
      findsNothing,
      reason: 'from and to are one rich line',
    );
    expect(_next(tester).onPressed, isNull);
  });

  testWidgets('entering the full price shows commission and payout', (
    tester,
  ) async {
    final draft = _draft();
    await _pump(tester, draft);

    await tester.tap(_key('price-full'));
    await tester.enterText(_key('price-full'), '1200');
    await tester.pump();

    expect(draft.fullPrice, 1200);
    expect(
      find.descendant(of: _key('price-total'), matching: find.text('1 320 ₽')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('price-commission'),
        matching: find.text('120 ₽'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('price-driver-gets'),
        matching: find.text('1 200 ₽'),
      ),
      findsOneWidget,
    );
    // The summary appeared above, but typing continues in the same field.
    expect(
      tester.widget<EditableText>(_input('price-full')).focusNode.hasFocus,
      isTrue,
    );
    expect(_next(tester).onPressed, isNotNull);
  });

  testWidgets('stops require a price for every leg', (tester) async {
    final draft = _draft(withStop: true);
    await _pump(tester, draft);
    final s = draft.stops;

    expect(find.text('Между остановками'), findsOneWidget);
    await tester.enterText(_key('price-full'), '1200');
    await tester.enterText(_key('price-segment-${s[0].id}-${s[1].id}'), '600');
    await tester.pump();
    expect(_next(tester).onPressed, isNull);

    await tester.enterText(_key('price-segment-${s[1].id}-${s[2].id}'), '700');
    await tester.pump();
    expect(_next(tester).onPressed, isNotNull);
    expect(draft.segmentPrice(s[1], s[2]), 700);
  });

  testWidgets('boarding price above the full price is an error', (
    tester,
  ) async {
    final draft = _draft();
    await _pump(tester, draft);

    await tester.enterText(_key('price-full'), '500');
    await tester.enterText(_key('price-min'), '600');
    await tester.pump();

    expect(find.text('Не больше цены всего маршрута'), findsOneWidget);
    expect(_next(tester).onPressed, isNull);
  });

  testWidgets('only digits up to 100 000 are accepted', (tester) async {
    final draft = _draft();
    await _pump(tester, draft);

    await tester.enterText(_key('price-full'), '12a3');
    await tester.pump();
    expect(draft.fullPrice, 123);

    await tester.enterText(_key('price-full'), '150000');
    await tester.pump();
    expect(draft.fullPrice, isNot(150000));
  });

  testWidgets('"Далее" calls onNext', (tester) async {
    var calls = 0;
    final draft = _draft()..fullPrice = 900;
    await _pump(tester, draft, onNext: () => calls++);

    await tester.tap(_key('new-trip-next'));

    expect(calls, 1);
  });

  test('commission matches the backend: 10 %, half up', () {
    expect(commissionFor(1000), 100);
    expect(passengerPriceFor(1000), 1100);
    expect(commissionFor(5), 1);
    expect(commissionFor(4), 0);
    expect(commissionFor(15), 2);
  });

  test('segment prices survive editing the route', () {
    final draft = _draft(withStop: true);
    final s = draft.stops;
    draft.setSegmentPrice(s[0], s[1], 600);

    draft.updateStop(2, text: 'Вокзал, Могилев', city: _mogilev);

    expect(draft.segmentPrice(draft.stops[0], draft.stops[1]), 600);
  });

  test('formatRubles groups thousands', () {
    expect(formatRubles(50), '50 ₽');
    expect(formatRubles(1250), '1 250 ₽');
    expect(formatRubles(100000), '100 000 ₽');
  });
}

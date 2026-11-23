import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/create_trip/trip_type_step_page.dart';

Future<VehicleType?> _pump(
  WidgetTester tester, {
  VehicleType initial = VehicleType.car,
  List<VehicleType>? chosen,
  VoidCallback? onBack,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: TripTypeStepPage(
        initialType: initial,
        onNext: (type) => chosen?.add(type),
        onBack: onBack,
      ),
    ),
  );
  return null;
}

void main() {
  testWidgets('shows step 1 of 4 with both vehicle types', (tester) async {
    await _pump(tester);

    expect(find.text('Новый заказ'), findsOneWidget);
    expect(find.text('Шаг 1 из 6'), findsOneWidget);
    expect(find.text('Тип заказа'), findsOneWidget);
    expect(find.text('Автомобиль'), findsOneWidget);
    expect(find.text('Автобус'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('car is selected by default and goes next', (tester) async {
    final chosen = <VehicleType>[];
    await _pump(tester, chosen: chosen);

    await tester.tap(find.byKey(const ValueKey('new-trip-next')));

    expect(chosen, [VehicleType.car]);
  });

  testWidgets('tapping the bus card selects the bus', (tester) async {
    final chosen = <VehicleType>[];
    await _pump(tester, chosen: chosen);

    await tester.tap(find.byKey(const ValueKey('trip-type-bus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-trip-next')));

    expect(chosen, [VehicleType.bus]);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('trip-type-bus'))),
      matchesSemantics(
        isSelected: true,
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        label: 'Автобус. Маршрутка или автобус, до 60 мест',
        hasTapAction: true,
      ),
    );
  });

  testWidgets('keeps the previously chosen type', (tester) async {
    final chosen = <VehicleType>[];
    await _pump(tester, initial: VehicleType.bus, chosen: chosen);

    await tester.tap(find.byKey(const ValueKey('new-trip-next')));

    expect(chosen, [VehicleType.bus]);
  });

  testWidgets('back button calls onBack', (tester) async {
    var backs = 0;
    await _pump(tester, onBack: () => backs++);

    await tester.tap(find.byKey(const ValueKey('new-trip-back')));

    expect(backs, 1);
  });

  test('draft notifies on vehicle type change and resets', () {
    final draft = TripDraft();
    var notified = 0;
    draft.addListener(() => notified++);

    draft.vehicleType = VehicleType.bus;
    draft.vehicleType = VehicleType.bus;
    expect(draft.vehicleType.apiValue, 'bus');
    expect(notified, 1);

    draft.reset();
    expect(draft.vehicleType, VehicleType.car);
    draft.dispose();
  });
}

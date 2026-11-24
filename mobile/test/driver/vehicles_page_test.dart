import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_car.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';
import 'package:put/src/features/driver/presentation/vehicles/vehicles_page.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _pump(
  WidgetTester tester,
  Future<List<DriverCar>> Function() loadCars, {
  Future<void> Function()? onAddCar,
  Future<void> Function(DriverCar)? onOpenCar,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VehiclesPage(
        loadCars: loadCars,
        onAddCar: onAddCar,
        onOpenCar: onOpenCar,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no vehicles: empty state with "Добавить ТС"', (tester) async {
    var loads = 0;
    var added = 0;
    await _pump(tester, () async {
      loads++;
      return const [];
    }, onAddCar: () async => added++);

    expect(find.text('Транспортные средства'), findsOneWidget);
    expect(find.text('У вас еще нет транспортного средства'), findsOneWidget);
    expect(
      find.text('Добавьте информацию о ТС и берите или создавайте заказы'),
      findsOneWidget,
    );

    await tester.tap(_key('vehicles-add-empty'));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(loads, 2, reason: 'the list reloads after adding');
  });

  testWidgets('lists vehicles; card opens, bottom button adds', (tester) async {
    final opened = <String>[];
    var added = 0;
    var loads = 0;
    await _pump(
      tester,
      () async {
        loads++;
        return const [
          DriverCar(
            id: 'c1',
            brand: 'Toyota',
            model: 'Camry',
            vehicleType: VehicleType.car,
            seats: 4,
            plate: '7841НХ-7',
          ),
          DriverCar(
            id: 'b1',
            brand: 'ПАЗ',
            model: '3205',
            vehicleType: VehicleType.bus,
            seats: 30,
          ),
        ];
      },
      onAddCar: () async => added++,
      onOpenCar: (car) async => opened.add(car.id),
    );

    expect(_key('vehicles-empty'), findsNothing);
    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('7841НХ-7 • 4 места'), findsOneWidget);
    expect(find.text('30 мест'), findsOneWidget);

    await tester.tap(_key('vehicle-c1'));
    await tester.pumpAndSettle();
    expect(opened, ['c1']);

    await tester.tap(_key('vehicles-add'));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(loads, 3, reason: 'reloads after opening and after adding');
  });

  testWidgets('load error offers a retry', (tester) async {
    var calls = 0;
    await _pump(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return const [];
    });

    expect(find.text('Не удалось загрузить транспорт'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(_key('vehicles-empty'), findsOneWidget);
  });
}

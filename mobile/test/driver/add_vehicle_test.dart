import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_api_exception.dart';
import 'package:put/src/features/driver/presentation/vehicles/add_vehicle_page.dart';
import 'package:put/src/features/driver/presentation/vehicles/catalog_picker_sheet.dart';
import 'package:put/src/features/driver/presentation/vehicles/sts_page.dart';
import 'package:put/src/features/driver/presentation/widgets/photo_source_sheet.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

// A valid 1×1 PNG.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _brands = [
  CatalogItem(id: 1, name: 'Abarth'),
  CatalogItem(id: 2, name: 'Audi'),
  CatalogItem(id: 3, name: 'BMW'),
  CatalogItem(id: 4, name: 'Infiniti'),
  CatalogItem(id: 5, name: 'Isuzu'),
];

const _models = [
  CatalogItem(id: 41, name: 'EX'),
  CatalogItem(id: 42, name: 'Q30'),
  CatalogItem(id: 43, name: 'Q50'),
];

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function(NewVehicle) onSubmit,
  List<PhotoSource>? picks,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AddVehiclePage(
        loadBrands: () async => _brands,
        loadModels: (id) async => id == 4 ? _models : const [],
        pickPhoto: (source) async {
          picks?.add(source);
          return PickedPhoto(bytes: _png, fileName: 'car.png');
        },
        openSts: (_) async => PickedPhoto(bytes: _png, fileName: 'sts.png'),
        onSubmit: onSubmit,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseBrandAndModel(WidgetTester tester) async {
  await tester.tap(_key('vehicle-brand'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('catalog-search'), 'i');
  await tester.pump();
  await tester.tap(_key('catalog-item-4'));
  await tester.pumpAndSettle();
  await tester.tap(_key('vehicle-model'));
  await tester.pumpAndSettle();
  await tester.tap(_key('catalog-item-42'));
  await tester.pumpAndSettle();
}

FilledButton _submit(WidgetTester tester) =>
    tester.widget<FilledButton>(_key('vehicle-submit'));

void main() {
  testWidgets('brand sheet groups by letter and searches', (tester) async {
    await _pump(tester, onSubmit: (_) async {});

    expect(find.text('Добавление нового ТС'), findsOneWidget);
    expect(_key('vehicle-seats'), findsNothing, reason: 'appears after brand');
    expect(_submit(tester).onPressed, isNull);

    await tester.tap(_key('vehicle-brand'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать марку автомобиля'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.enterText(_key('catalog-search'), 'IS');
    await tester.pump();
    expect(find.text('Isuzu'), findsOneWidget);
    expect(find.text('Audi'), findsNothing);
  });

  testWidgets('full form: brand, model, seats, photo, type, СТС', (
    tester,
  ) async {
    NewVehicle? sent;
    final picks = <PhotoSource>[];
    await _pump(tester, onSubmit: (v) async => sent = v, picks: picks);

    await _chooseBrandAndModel(tester);
    expect(find.text('Infiniti'), findsOneWidget);
    expect(find.text('Q30'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: _key('vehicle-seats'),
        matching: find.byType(EditableText),
      ),
      '6',
    );
    await tester.enterText(
      find.descendant(
        of: _key('vehicle-plate'),
        matching: find.byType(EditableText),
      ),
      'А777АА66',
    );
    await tester.pump();
    expect(_submit(tester).onPressed, isNull, reason: 'type is required');

    await tester.tap(_key('vehicle-add-photo'));
    await tester.pumpAndSettle();
    expect(find.text('Загрузка фотографии'), findsOneWidget);
    await tester.tap(_key('photo-files'));
    await tester.pumpAndSettle();
    expect(picks, [PhotoSource.files]);
    expect(_key('vehicle-photo'), findsOneWidget);

    await tester.tap(_key('vehicle-type-car'));
    await tester.pump();
    await tester.tap(_key('vehicle-sts'));
    await tester.pumpAndSettle();
    expect(find.text('Фото добавлено'), findsOneWidget);

    await tester.tap(_key('vehicle-submit'));
    await tester.pumpAndSettle();

    expect(sent!.toJson(), {
      'model_id': 42,
      'vehicle_type': 'car',
      'seats': 6,
      'plate': 'А777АА66',
    });
    expect(sent!.photo!.fileName, 'car.png');
    expect(sent!.sts!.fileName, 'sts.png');
  });

  testWidgets('too many seats for a car is flagged', (tester) async {
    await _pump(tester, onSubmit: (_) async {});
    await _chooseBrandAndModel(tester);

    await tester.enterText(
      find.descendant(
        of: _key('vehicle-seats'),
        matching: find.byType(EditableText),
      ),
      '12',
    );
    await tester.tap(_key('vehicle-type-car'));
    await tester.pump();
    expect(_key('vehicle-seats-error'), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);

    await tester.tap(_key('vehicle-type-bus'));
    await tester.pump();
    expect(_key('vehicle-seats-error'), findsNothing);
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('changing the brand clears the model; photo can be removed', (
    tester,
  ) async {
    await _pump(tester, onSubmit: (_) async {});
    await _chooseBrandAndModel(tester);

    await tester.tap(_key('vehicle-add-photo'));
    await tester.pumpAndSettle();
    await tester.tap(_key('photo-camera'));
    await tester.pumpAndSettle();
    await tester.tap(_key('vehicle-photo-remove'));
    await tester.pump();
    expect(_key('vehicle-add-photo'), findsOneWidget);

    await tester.tap(_key('vehicle-brand'));
    await tester.pumpAndSettle();
    await tester.tap(_key('catalog-item-3'));
    await tester.pumpAndSettle();
    expect(find.text('BMW'), findsOneWidget);
    expect(find.text('Q30'), findsNothing);
  });

  testWidgets('server error is shown', (tester) async {
    await _pump(
      tester,
      onSubmit: (_) async =>
          throw const DriverApiException('Для автобуса не больше 60 мест'),
    );
    await _chooseBrandAndModel(tester);
    await tester.enterText(
      find.descendant(
        of: _key('vehicle-seats'),
        matching: find.byType(EditableText),
      ),
      '4',
    );
    await tester.tap(_key('vehicle-type-car'));
    await tester.pump();
    await tester.tap(_key('vehicle-submit'));
    await tester.pumpAndSettle();

    expect(find.text('Для автобуса не больше 60 мест'), findsOneWidget);
  });

  testWidgets('СТС: take a photo, check it, done', (tester) async {
    PickedPhoto? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await Navigator.of(context).push<PickedPhoto>(
                  MaterialPageRoute(
                    builder: (_) => StsPage(
                      pickPhoto: (_) async =>
                          PickedPhoto(bytes: _png, fileName: 'sts.png'),
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

    expect(find.text('СТС (свидетельство о регистрации)'), findsOneWidget);
    await tester.tap(_key('sts-primary'));
    await tester.pumpAndSettle();
    await tester.tap(_key('photo-camera'));
    await tester.pumpAndSettle();
    expect(_key('sts-preview'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);

    await tester.tap(_key('sts-primary'));
    await tester.pumpAndSettle();
    expect(result?.fileName, 'sts.png');
  });
}

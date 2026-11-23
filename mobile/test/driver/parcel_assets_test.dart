import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/trip_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every parcel size has its picture bundled', () async {
    for (final size in ParcelSize.values) {
      final path =
          'assets/images/driver/parcel_${size.value.toLowerCase()}.png';
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });
}

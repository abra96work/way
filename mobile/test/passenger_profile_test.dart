import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/presentation/widgets/photo_source_sheet.dart';
import 'package:put/src/features/trips/domain/passenger_profile.dart';
import 'package:put/src/features/trips/presentation/passenger_personal_data_page.dart';
import 'package:put/src/features/trips/presentation/passenger_profile_page.dart';
import 'package:put/src/features/trips/presentation/passenger_role_page.dart';

void main() {
  const profile = PassengerProfile(
    firstName: 'Анастасия',
    lastName: null,
    avatarUrl: null,
    rating: 5,
    reviewsCount: 0,
    completedTrips: 0,
    phone: '+79001234567',
  );

  test('passenger profile prefixes relative avatar URLs', () {
    final value = PassengerProfile.fromJson({
      'first_name': 'Анна',
      'avatar_url': '/media/avatar.png',
      'rating': 4.8,
      'reviews_count': 2,
      'completed_trips': 12,
      'phone': '+79001234567',
    }, mediaBaseUrl: 'http://localhost:8000');

    expect(value.avatarUrl, 'http://localhost:8000/media/avatar.png');
    expect(value.ratingLabel, '4,8');
  });

  testWidgets('passenger profile shows API data and confirms logout', (
    tester,
  ) async {
    _setViewport(tester);
    var loggedOut = false;
    final opened = <PassengerProfileSection>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerProfilePage(
          loadProfile: () async => profile,
          loadUnreadNotifications: () async => 3,
          onOpen: opened.add,
          onLogout: () async => loggedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Анастасия'), findsOneWidget);
    expect(find.text('5,0 · нет отзывов'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('passenger-profile-personal')));
    expect(opened, [PassengerProfileSection.personal]);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('passenger-profile-logout')),
      250,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passenger-profile-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Выйдите из аккаунта?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('passenger-logout-confirm')));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });

  testWidgets('role page switches to driver mode', (tester) async {
    _setViewport(tester);
    var driver = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerRolePage(onBack: () {}, onDriver: () => driver = true),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('passenger-role-driver')));
    expect(driver, isTrue);
  });

  testWidgets('personal data saves changed name and formats phone', (
    tester,
  ) async {
    _setViewport(tester);
    String? savedName;
    String? savedLastName;
    PickedPhoto? savedPhoto;
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerPersonalDataPage(
          loadProfile: () async => profile,
          pickPhoto: (_) async => null,
          onSave: (name, lastName, photo) async {
            savedName = name;
            savedLastName = lastName;
            savedPhoto = photo;
          },
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+7 900 123 45 67'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('passenger-personal-name')),
      'Анна',
    );
    await tester.enterText(
      find.byKey(const ValueKey('passenger-personal-last-name')),
      'Иванова',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('passenger-personal-save')));
    await tester.pumpAndSettle();
    expect(savedName, 'Анна');
    expect(savedLastName, 'Иванова');
    expect(savedPhoto, isNull);
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

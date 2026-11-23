import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/features/driver/domain/driver_profile.dart';
import 'package:put/src/features/driver/presentation/profile/driver_profile_page.dart';
import 'package:put/src/features/driver/presentation/widgets/driver_nav_bar.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _pump(
  WidgetTester tester, {
  DriverProfile profile = const DriverProfile(
    firstName: 'Анастасия',
    rating: 4.8,
    reviewsCount: 12,
    completedTrips: 120,
  ),
  int unread = 1,
  ValueChanged<ProfileSection>? onOpen,
  Future<void> Function()? onLogout,
  ValueChanged<DriverTab>? onTab,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: DriverProfilePage(
        loadProfile: () async => profile,
        loadUnreadNotifications: () async => unread,
        onOpen: onOpen ?? (_) {},
        onLogout: onLogout ?? () async {},
        onTab: onTab ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows name, rating, trips and the menu', (tester) async {
    await _pump(tester);

    expect(find.text('Мой профиль'), findsOneWidget);
    expect(find.text('Анастасия'), findsOneWidget);
    expect(find.text('4,8'), findsOneWidget);
    expect(find.text('120 поездок'), findsOneWidget);
    expect(find.text('нет отзывов'), findsNothing);
    for (final section in ProfileSection.values) {
      await tester.scrollUntilVisible(find.text(section.title), 200);
      expect(find.text(section.title), findsOneWidget);
    }
    await tester.scrollUntilVisible(_key('profile-unread'), -200);
    expect(_key('profile-unread'), findsOneWidget);
    await tester.scrollUntilVisible(_key('profile-logout'), 200);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
  });

  testWidgets('new driver: "5,0 · нет отзывов", no badge', (tester) async {
    await _pump(
      tester,
      profile: const DriverProfile(firstName: 'Виктор'),
      unread: 0,
    );

    expect(find.text('5,0'), findsOneWidget);
    expect(find.text('нет отзывов'), findsOneWidget);
    expect(find.text('0 поездок'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Уведомления'), 200);
    expect(_key('profile-unread'), findsNothing);
  });

  testWidgets('menu rows and tabs call back', (tester) async {
    final opened = <ProfileSection>[];
    final tabs = <DriverTab>[];
    await _pump(tester, onOpen: opened.add, onTab: tabs.add);

    await tester.tap(_key('profile-vehicles'));
    await tester.tap(_key('nav-create'));
    await tester.tap(_key('nav-orders'));

    expect(opened, [ProfileSection.vehicles]);
    expect(tabs, [DriverTab.create, DriverTab.orders]);
  });

  testWidgets('sign-out asks first', (tester) async {
    var loggedOut = 0;
    await _pump(tester, onLogout: () async => loggedOut++);

    await tester.scrollUntilVisible(_key('profile-logout'), 200);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(_key('profile-logout'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(loggedOut, 0);

    await tester.tap(_key('profile-logout'));
    await tester.pumpAndSettle();
    await tester.tap(_key('logout-confirm'));
    await tester.pumpAndSettle();
    expect(loggedOut, 1);
  });

  test('profile json and labels', () {
    final p = DriverProfile.fromJson({
      'first_name': 'Анастасия',
      'last_name': null,
      'avatar_url': '/media/avatars/a.jpg',
      'rating': 4.75,
      'reviews_count': 3,
      'completed_trips': 21,
    }, mediaBaseUrl: 'https://api.example');

    expect(p.avatarUrl, 'https://api.example/media/avatars/a.jpg');
    expect(p.ratingLabel, '4,8');
    expect(tripsLabel(21), '21 поездка');
    expect(tripsLabel(3), '3 поездки');
    expect(tripsLabel(11), '11 поездок');
  });
}

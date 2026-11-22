import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/app.dart';
import 'package:put/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:put/src/features/onboarding/presentation/registration_intro_page.dart';
import 'package:put/src/features/onboarding/presentation/role_selection_page.dart';
import 'package:put/src/features/onboarding/presentation/welcome_page.dart';

void main() {
  testWidgets('shows the first onboarding screen', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.pump();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-logo')), findsOneWidget);
    expect(find.text('Путь'), findsOneWidget);
    expect(find.text('Попутчики и посылки по вашему маршруту'), findsOneWidget);
    expect(find.text('Начать'), findsOneWidget);
    expect(find.text('Уже есть аккаунт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('start opens the welcome screen', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Добро пожаловать\nв Путь'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('welcome-location-image')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Находите нужное направление, создавайте поездки\n'
        'или бронируйте места,\n'
        'экономьте время и деньги',
      ),
      findsOneWidget,
    );
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('continue action is wired', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.tap(find.text('Продолжить'));
    await tester.pump();

    expect(find.text('Следующий экран появится далее'), findsOneWidget);
  });

  testWidgets('welcome continue opens the registration intro', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationIntroPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('registration-header-logo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('registration-car-image')),
      findsOneWidget,
    );
    expect(find.text('Добро пожаловать\nв Путь'), findsOneWidget);
    expect(
      find.text(
        'Зарегистрируйтесь,\n'
        'чтобы начать\n'
        'пользоваться\n'
        'приложением.',
      ),
      findsOneWidget,
    );
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration continue action is wired', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: RegistrationIntroPage()));
    await tester.tap(find.text('Продолжить'));
    await tester.pump();

    expect(find.text('Регистрация появится далее'), findsOneWidget);
  });

  testWidgets('registration continue opens role selection', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.byType(RoleSelectionPage), findsOneWidget);
    expect(
      find.text('От чьего лица вы хотите\nсоздать поездку?'),
      findsOneWidget,
    );
    expect(find.text('Водитель'), findsOneWidget);
    expect(find.text('Пассажир'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role cards change the selected role', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: RoleSelectionPage()));

    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('driver-role')))
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('passenger-role')));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('passenger-role')))
          .properties
          .selected,
      isTrue,
    );
  });
}

void _setReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

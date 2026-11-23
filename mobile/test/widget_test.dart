import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:put/src/app.dart';
import 'package:put/src/features/auth/presentation/legal_document_page.dart';
import 'package:put/src/features/auth/presentation/phone_login_page.dart';
import 'package:put/src/features/auth/presentation/profile_registration_page.dart';
import 'package:put/src/features/auth/presentation/sms_code_page.dart';
import 'package:put/src/features/onboarding/presentation/city_selection_page.dart';
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

  testWidgets('existing account opens phone login', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.tap(find.text('Уже есть аккаунт'));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneLoginPage), findsOneWidget);
    expect(find.text('Добро пожаловать в «Путь»!'), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone is formatted and code request is enabled', (tester) async {
    _setReferenceViewport(tester);
    String? requestedPhone;

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginPage(
          onRequestCode: (phone) async => requestedPhone = phone,
        ),
      ),
    );

    final button = find.byKey(const ValueKey('phone-request-code'));
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('phone-input')),
      '257774420',
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('phone-input')),
    );
    expect(field.controller?.text, '+375 25 777 44 20');
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requestedPhone, '+375257774420');
    expect(find.text('Код для входа отправлен'), findsOneWidget);
  });

  testWidgets('terms link opens legal document', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.tap(find.text('Уже есть аккаунт'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terms-link')));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentPage), findsOneWidget);
    expect(find.text('Условия использования'), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-scroll')), findsOneWidget);
  });

  testWidgets('sms code screen starts in the disabled state', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: SmsCodePage(
          phone: '+375257774420',
          onVerify: (_, _) async {},
          onResend: (_) async {},
        ),
      ),
    );

    expect(find.text('СМС-код'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('+375 25 777 44 20'),
      ),
      findsOneWidget,
    );
    expect(find.text('_'), findsNWidgets(6));
    expect(find.text('0:59'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('sms-login-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('six sms digits enable verification', (tester) async {
    _setReferenceViewport(tester);
    String? verifiedPhone;
    String? verifiedCode;

    await tester.pumpWidget(
      MaterialApp(
        home: SmsCodePage(
          phone: '+375257774420',
          onVerify: (phone, code) async {
            verifiedPhone = phone;
            verifiedCode = code;
          },
          onResend: (_) async {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sms-code-input')),
      '377991',
    );
    await tester.pump();

    final button = find.byKey(const ValueKey('sms-login-button'));
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pump();

    expect(verifiedPhone, '+375257774420');
    expect(verifiedCode, '377991');
  });

  testWidgets('invalid sms code shows the designed error state', (
    tester,
  ) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: SmsCodePage(
          phone: '+375257774420',
          initialSeconds: 0,
          onVerify: (_, _) async => throw Exception('invalid_code'),
          onResend: (_) async {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sms-code-input')),
      '133229',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sms-login-button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Неверный код подтверждения'), findsOneWidget);
    expect(find.byKey(const ValueKey('sms-invalid-code')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('sms-login-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('sms code can be requested again after timeout', (tester) async {
    _setReferenceViewport(tester);
    var resendCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SmsCodePage(
          phone: '+375257774420',
          initialSeconds: 0,
          onVerify: (_, _) async {},
          onResend: (_) async => resendCount++,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('sms-resend-button')));
    await tester.pump();

    expect(resendCount, 1);
    expect(find.byKey(const ValueKey('sms-resend-timer')), findsOneWidget);
    expect(find.text('0:59'), findsOneWidget);
  });

  testWidgets('profile registration starts disabled', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(
      MaterialApp(home: ProfileRegistrationPage(onSave: (_, _) async {})),
    );

    expect(find.text('Создайте свой профиль'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-name-input')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('profile-continue')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile photo opens camera and gallery sheet', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(
      MaterialApp(home: ProfileRegistrationPage(onSave: (_, _) async {})),
    );
    await tester.tap(find.byKey(const ValueKey('profile-photo')));
    await tester.pumpAndSettle();

    expect(find.text('Загрузка фотографии'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-photo-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-photo-gallery')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed profile is submitted with loading state', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    final saveCompleter = Completer<void>();
    String? savedName;
    SelectedProfilePhoto? savedPhoto;
    var completed = false;
    final photo = SelectedProfilePhoto(
      bytes: _onePixelPng(),
      fileName: 'avatar.png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileRegistrationPage(
          pickPhoto: (_) async => photo,
          onSave: (name, selectedPhoto) {
            savedName = name;
            savedPhoto = selectedPhoto;
            return saveCompleter.future;
          },
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-photo-gallery')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-input')),
      '  Анастасия  ',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('profile-photo-preview')), findsOneWidget);
    final button = find.byKey(const ValueKey('profile-continue'));
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-loading')), findsOneWidget);
    expect(savedName, 'Анастасия');
    expect(savedPhoto, same(photo));

    saveCompleter.complete();
    await tester.pump();
    expect(completed, isTrue);
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

  testWidgets('role selection opens city selection', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const PutApp());
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('driver-role')));
    await tester.pumpAndSettle();

    expect(find.byType(CitySelectionPage), findsOneWidget);
    expect(find.text('Выберите ваш город'), findsOneWidget);
    expect(find.text('Абакан'), findsOneWidget);
    expect(find.text('Владивосток'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('city search filters the list', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: CitySelectionPage()));
    await tester.enterText(find.byKey(const ValueKey('city-search')), 'Влади');
    await tester.pump();

    expect(find.text('Владивосток'), findsOneWidget);
    expect(find.text('Владикавказ'), findsOneWidget);
    expect(find.text('Владимир'), findsOneWidget);
    expect(find.text('Абакан'), findsNothing);
  });

  testWidgets('city search can be cleared while focused', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: CitySelectionPage()));
    await tester.enterText(find.byKey(const ValueKey('city-search')), 'Москва');
    await tester.pump();
    expect(find.byKey(const ValueKey('city-search-clear')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('city-search-clear')));
    await tester.pump();

    expect(find.text('Абакан'), findsOneWidget);
    expect(find.byKey(const ValueKey('city-search-clear')), findsNothing);
  });

  testWidgets('selected city shows continue and hides results', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: CitySelectionPage()));
    await tester.enterText(find.byKey(const ValueKey('city-search')), 'Москва');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('city-Москва')));
    await tester.pump();

    expect(find.byKey(const ValueKey('city-list')), findsNothing);
    expect(find.byKey(const ValueKey('city-continue')), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('city selection callback receives the city', (tester) async {
    _setReferenceViewport(tester);
    String? selectedCity;

    await tester.pumpWidget(
      MaterialApp(
        home: CitySelectionPage(onCitySelected: (city) => selectedCity = city),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('city-Абакан')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('city-continue')));

    expect(selectedCity, 'Абакан');
  });
}

void _setReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Uint8List _onePixelPng() {
  const hex =
      '89504e470d0a1a0a0000000d4948445200000001000000010806000000'
      '1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082';
  return Uint8List.fromList([
    for (var index = 0; index < hex.length; index += 2)
      int.parse(hex.substring(index, index + 2), radix: 16),
  ]);
}

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
import 'package:put/src/features/trips/domain/passenger_trip.dart';
import 'package:put/src/features/trips/domain/passenger_booking.dart';
import 'package:put/src/features/trips/presentation/passenger_booking_dialogs.dart';
import 'package:put/src/features/trips/presentation/passenger_booking_success_page.dart';
import 'package:put/src/features/trips/presentation/passenger_account_blocked_page.dart';
import 'package:put/src/features/trips/presentation/passenger_address_search_sheet.dart';
import 'package:put/src/features/trips/presentation/passenger_trip_detail_page.dart';
import 'package:put/src/features/trips/presentation/passenger_trips_page.dart';
import 'package:put/src/features/trips/services/passenger_location_service.dart';

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
      '9001234567',
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('phone-input')),
    );
    expect(field.controller?.text, '+7 900 123 45 67');
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requestedPhone, '+79001234567');
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

  testWidgets('sms code shows the Russian API error message', (tester) async {
    _setReferenceViewport(tester);
    final request = RequestOptions(path: '/auth/verify-code');

    await tester.pumpWidget(
      MaterialApp(
        home: SmsCodePage(
          phone: '+79001234567',
          initialSeconds: 0,
          onVerify: (_, _) async => throw DioException(
            requestOptions: request,
            response: Response<Map<String, dynamic>>(
              requestOptions: request,
              statusCode: 429,
              data: const {
                'code': 'too_many_attempts',
                'message': 'Слишком много попыток. Запросите новый код',
              },
            ),
          ),
          onResend: (_) async {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('sms-code-input')),
      '111111',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sms-login-button')));
    await tester.pump();

    expect(
      find.text('Слишком много попыток. Запросите новый код'),
      findsOneWidget,
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

  testWidgets('passenger trips show the designed empty state', (tester) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(const MaterialApp(home: PassengerTripsPage()));

    expect(find.byKey(const ValueKey('passenger-trips-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('passenger-trips-empty')), findsOneWidget);
    expect(find.text('Здесь ещё нет заказов'), findsOneWidget);
    expect(find.text('Автомобили'), findsOneWidget);
    expect(find.text('Автобусы'), findsOneWidget);
  });

  testWidgets('passenger trip list filters vehicles and opens a trip', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    PassengerTrip? openedTrip;
    final trip = _samplePassengerTrip();

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripsPage(
          initialTrips: [trip],
          onTripPressed: (value) => openedTrip = value,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('passenger-trip-trip-1')), findsOneWidget);
    expect(find.text('Виктор О.'), findsOneWidget);
    expect(find.text('1 800 ₽'), findsOneWidget);
    expect(find.text('Идёт регистрация пассажиров'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('passenger-trip-trip-1')));
    expect(openedTrip, same(trip));

    await tester.tap(find.byKey(const ValueKey('passenger-buses-tab')));
    await tester.pump();
    expect(find.byKey(const ValueKey('passenger-trips-empty')), findsOneWidget);
  });

  testWidgets('address search provides route creation suggestions', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    PassengerAddressSuggestion? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showPassengerAddressSearchSheet(context);
              },
              child: const Text('open address search'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open address search'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('passenger-address-search-sheet')),
      findsOneWidget,
    );
    expect(find.text('Моё местоположение'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('passenger-address-query')),
      'Московский',
    );
    await tester.pump();
    expect(find.text('Московский, 56'), findsOneWidget);
    expect(find.text('Адрес'), findsNothing);
    await tester.tap(find.text('Московский, 56'));
    await tester.pumpAndSettle();
    expect(selected?.title, 'Московский, 56');
    expect(tester.takeException(), isNull);
  });

  testWidgets('passenger trip details expose route and actions', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    var booked = false;
    var parcelSent = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripDetailPage(
          initialDetails: _samplePassengerTripDetails(),
          onBookSeat: (draft) async {
            booked = true;
            expect(draft.fromPosition, 0);
            expect(draft.toPosition, 3);
            expect(draft.seats, 1);
          },
          onSendParcel: (_) async => parcelSent = true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('passenger-trip-details')),
      findsOneWidget,
    );
    expect(find.text('Улица Солнечная, дом 1'), findsOneWidget);
    expect(find.text('Улица Лунная, дом 2'), findsOneWidget);
    expect(find.text('Улица Ленина, дом 5'), findsOneWidget);
    expect(find.text('Улица Пушкина, дом 10'), findsOneWidget);
    expect(find.text('Виктор О.'), findsOneWidget);
    expect(find.text('1 из 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('passenger-book-seat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seat-booking-sheet')), findsOneWidget);
    expect(find.text('Откликнуться на заказ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seat-booking-submit')));
    await tester.pumpAndSettle();
    expect(booked, isTrue);

    await tester.tap(find.byKey(const ValueKey('passenger-send-parcel')));
    await tester.pumpAndSettle();
    expect(parcelSent, isFalse);
    expect(find.byKey(const ValueKey('parcel-booking-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('parcel-size-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Укажите размер вашей посылки'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('parcel-option-M')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('parcel-size-add')));
    await tester.pumpAndSettle();
    expect(find.text('Посылка M'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('parcel-continue-to-payment')));
    await tester.pumpAndSettle();
    expect(parcelSent, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('passenger-detail-price-toggle')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byKey(const ValueKey('passenger-trip-details')),
      const Offset(0, -140),
    );
    await tester.pump();
    expect(find.text('1 200 ₽'), findsOneWidget);
    expect(find.text('150 ₽'), findsNWidgets(3));

    await tester.tap(
      find.byKey(const ValueKey('passenger-detail-price-toggle')),
    );
    await tester.pump();
    expect(find.text('150 ₽'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip without seats disables booking and starts collapsed', (
    tester,
  ) async {
    _setReferenceViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripDetailPage(
          initialDetails: _samplePassengerTripDetails(seatsAvailable: 0),
          onBookSeat: (_) async {},
          onSendParcel: (_) async {},
        ),
      ),
    );

    expect(find.text('0 из 3'), findsOneWidget);
    expect(find.text('Мест нет'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('passenger-book-seat')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Улица Ленина, дом 5'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('passenger-detail-stops-toggle')),
    );
    await tester.pump();
    expect(find.text('Улица Ленина, дом 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking response dialogs cover accepted cancel and rejected', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showBookingAcceptedDialog(
                    context,
                    onPay: () async {},
                    onCancel: () async => cancelled = true,
                  ),
                  child: const Text('accepted'),
                ),
                TextButton(
                  onPressed: () => showBookingRejectedDialog(context),
                  child: const Text('rejected'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('accepted'));
    await tester.pumpAndSettle();
    expect(find.text('Водитель принял заявку'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-dialog-secondary')));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);

    await tester.tap(find.text('rejected'));
    await tester.pumpAndSettle();
    expect(find.text('Водитель отклонил заявку'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-dialog-primary')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancellation warnings follow backend sanction preview', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    var confirmed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showBookingCancellationDialog(
                    context,
                    preview: const PassengerCancellationInfo(
                      isViolation: true,
                      violationsLastPeriod: 0,
                      blocksAccount: false,
                    ),
                    onConfirm: () async => confirmed += 1,
                  ),
                  child: const Text('first cancellation'),
                ),
                TextButton(
                  onPressed: () => showBookingCancellationDialog(
                    context,
                    preview: const PassengerCancellationInfo(
                      isViolation: true,
                      violationsLastPeriod: 1,
                      blocksAccount: true,
                    ),
                    onConfirm: () async => confirmed += 1,
                  ),
                  child: const Text('blocking cancellation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('first cancellation'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить бронирование?'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('booking-cancellation-confirm')),
    );
    await tester.pumpAndSettle();
    expect(confirmed, 1);

    await tester.tap(find.text('blocking cancellation'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить бронирование?'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('booking-cancellation-confirm')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Это может повлиять'), findsOneWidget);
    expect(find.textContaining('одна отмена'), findsOneWidget);
    expect(confirmed, 1);
    await tester.tap(
      find.byKey(const ValueKey('booking-cancellation-confirm')),
    );
    await tester.pumpAndSettle();
    expect(confirmed, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked account result has the designed final screen', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    var acknowledged = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PassengerAccountBlockedPage(
          onAcknowledged: () => acknowledged = true,
        ),
      ),
    );

    expect(find.text('Аккаунт временно\nзаблокирован'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-blocked-illustration')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('account-blocked-acknowledge')));
    expect(acknowledged, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paid booking exposes success and paid trip states', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    var openedTrips = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerBookingSuccessPage(
          onMyTrips: () => openedTrips = true,
          onMessageDriver: () {},
        ),
      ),
    );
    expect(find.text('Место забронировано'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-success-my-trips')));
    expect(openedTrips, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripDetailPage(
          initialDetails: _samplePassengerTripDetails(),
          booking: _samplePaidBooking(),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('passenger-paid-price-card')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('passenger-paid-price-card')),
      findsOneWidget,
    );
    expect(find.text('50 ₽'), findsOneWidget);
    expect(find.text('1 150 ₽'), findsOneWidget);
    expect(find.byKey(const ValueKey('passenger-paid-cancel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('passenger-paid-message')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('passenger filters map to backend search parameters', () {
    final manual = PassengerTripFilter.manual(
      from: ' Екатеринбург ',
      to: 'Асбест',
    );
    expect(manual.toQueryParameters('car'), {
      'vehicle_type': 'car',
      'from_query': 'Екатеринбург',
      'to_query': 'Асбест',
    });

    final nearby = PassengerTripFilter.nearby(
      latitude: 56.91,
      longitude: 60.80,
      radiusKm: 5,
    );
    expect(nearby.toQueryParameters('bus'), {
      'vehicle_type': 'bus',
      'lat': 56.91,
      'lng': 60.80,
      'radius_km': 5.0,
    });
  });

  testWidgets('skipping location opens manual city filters', (tester) async {
    _setReferenceViewport(tester);
    final filters = <PassengerTripFilter>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripsPage(
          locationService: _FakeLocationService(null),
          loadTrips: (_, filter) async {
            filters.add(filter);
            return const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('passenger-filter')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('location-access-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('location-access-skip')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('passenger-filter-sheet')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('passenger-filter-from')),
      'Екатеринбург',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('passenger-filter-apply')));
    await tester.pumpAndSettle();

    expect(filters.last.fromQuery, 'Екатеринбург');
    expect(
      find.byKey(const ValueKey('passenger-filter-active')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('passenger-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passenger-filter-clear')));
    await tester.pumpAndSettle();
    expect(filters.last.isActive, isFalse);
    expect(find.byKey(const ValueKey('passenger-filter-active')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('granted location applies nearby search', (tester) async {
    _setReferenceViewport(tester);
    final filters = <PassengerTripFilter>[];
    final location = _FakeLocationService(
      const PassengerCoordinates(latitude: 56.91, longitude: 60.80),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripsPage(
          locationService: location,
          loadTrips: (_, filter) async {
            filters.add(filter);
            return const [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passenger-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-access-allow')));
    await tester.pumpAndSettle();

    expect(location.requests, 1);
    expect(filters.last.latitude, 56.91);
    expect(filters.last.longitude, 60.80);
    expect(
      find.byKey(const ValueKey('passenger-filter-active')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('passenger-filter-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('denied location falls back to manual city search', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    final location = _FakeLocationService(null);

    await tester.pumpWidget(
      MaterialApp(
        home: PassengerTripsPage(
          locationService: location,
          loadTrips: (_, _) async => const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('passenger-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location-access-allow')));
    await tester.pumpAndSettle();

    expect(location.requests, 1);
    expect(find.text('Введите города вручную'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('passenger-filter-sheet')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeLocationService implements PassengerLocationService {
  _FakeLocationService(this.result);

  final PassengerCoordinates? result;
  int requests = 0;

  @override
  Future<PassengerCoordinates?> requestCurrentPosition() async {
    requests += 1;
    return result;
  }
}

PassengerTrip _samplePassengerTrip({bool isRegistrationOpen = true}) =>
    PassengerTrip(
      id: 'trip-1',
      departureAt: DateTime(2026, 5, 15, 9),
      vehicleType: 'car',
      driverName: 'Виктор О.',
      driverRating: 4.5,
      completedTrips: 127,
      driverAvatarUrl: null,
      carName: 'Toyota Camry',
      carPhotoUrl: null,
      carPlate: 'A 123 BC',
      boardAddress: 'Улица Солнечная, дом 1',
      alightAddress: 'Улица Лунная, дом 2',
      boardPosition: 0,
      alightPosition: 2,
      stopsCount: 3,
      distanceKm: 3.2,
      price: 1800,
      seatsAvailable: 1,
      extras: const ['pets', 'luggage'],
      acceptsParcels: true,
      isRegistrationOpen: isRegistrationOpen,
    );

PassengerTripDetails _samplePassengerTripDetails({int seatsAvailable = 1}) =>
    PassengerTripDetails(
      id: 'trip-1',
      departureAt: DateTime(2026, 5, 15, 8),
      driverName: 'Виктор О.',
      driverRating: 4.5,
      completedTrips: 127,
      driverAvatarUrl: null,
      carName: 'Toyota Camry',
      carPhotoUrl: null,
      carPlate: 'A 123 BC',
      stops: const [
        PassengerStop(position: 0, address: 'Улица Солнечная, дом 1'),
        PassengerStop(position: 1, address: 'Улица Ленина, дом 5'),
        PassengerStop(position: 2, address: 'Улица Пушкина, дом 10'),
        PassengerStop(position: 3, address: 'Улица Лунная, дом 2'),
      ],
      seatsTotal: 3,
      seatsAvailable: seatsAvailable,
      price: 1200,
      extras: const ['luggage', 'pets', 'child_seat'],
      extraOptions: const [
        PassengerExtraOption(kind: 'child_seat', price: 150),
        PassengerExtraOption(kind: 'luggage', price: 150),
        PassengerExtraOption(kind: 'pets', price: 150),
      ],
      parcelSizes: const ['S', 'M', 'L'],
      parcelOptions: const [
        PassengerParcelOption(
          size: 'S',
          maxDimensionsCm: [30, 30, 20],
          maxWeightKg: 5,
          price: 150,
        ),
        PassengerParcelOption(
          size: 'M',
          maxDimensionsCm: [50, 40, 30],
          maxWeightKg: 10,
          price: 250,
        ),
        PassengerParcelOption(
          size: 'L',
          maxDimensionsCm: [80, 60, 40],
          maxWeightKg: 20,
          price: 350,
        ),
      ],
      segmentPrices: const [
        PassengerSegmentPrice(fromPosition: 0, toPosition: 1, price: 150),
        PassengerSegmentPrice(fromPosition: 1, toPosition: 2, price: 150),
        PassengerSegmentPrice(fromPosition: 2, toPosition: 3, price: 150),
      ],
    );

PassengerBooking _samplePaidBooking() => const PassengerBooking(
  id: 'booking-1',
  tripId: 'trip-1',
  status: 'paid',
  price: 1200,
  commission: 50,
  payToDriver: 1150,
  canPay: false,
  canCancel: true,
);

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

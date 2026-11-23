import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/legal_document_page.dart';
import 'features/auth/presentation/phone_login_page.dart';
import 'features/auth/presentation/profile_registration_page.dart';
import 'features/auth/presentation/sms_code_page.dart';
import 'features/driver/domain/driver_api_exception.dart';
import 'features/driver/domain/driver_car.dart';
import 'features/driver/domain/driver_profile.dart';
import 'features/driver/domain/driver_trip.dart';
import 'features/driver/domain/trip_draft.dart';
import 'features/driver/presentation/create_trip/booking_step_page.dart';
import 'features/driver/presentation/create_trip/car_step_page.dart';
import 'features/driver/presentation/create_trip/extras_step_page.dart';
import 'features/driver/presentation/create_trip/price_step_page.dart';
import 'features/driver/presentation/create_trip/reverse_trip_page.dart';
import 'features/driver/presentation/create_trip/route_step_page.dart';
import 'features/driver/presentation/create_trip/trip_published_page.dart';
import 'features/driver/presentation/create_trip/trip_type_step_page.dart';
import 'features/driver/presentation/profile/driver_profile_page.dart';
import 'features/driver/presentation/trips/driver_trips_page.dart';
import 'features/driver/presentation/vehicles/add_vehicle_page.dart';
import 'features/driver/presentation/vehicles/catalog_picker_sheet.dart';
import 'features/driver/presentation/vehicles/vehicles_page.dart';
import 'features/driver/presentation/widgets/photo_source_sheet.dart';
import 'features/driver/presentation/widgets/driver_nav_bar.dart';
import 'features/onboarding/presentation/city_selection_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/onboarding/presentation/registration_intro_page.dart';
import 'features/onboarding/presentation/role_selection_page.dart';
import 'features/onboarding/presentation/welcome_page.dart';

class PutApp extends StatefulWidget {
  const PutApp({super.key});

  @override
  State<PutApp> createState() => _PutAppState();
}

class _PutAppState extends State<PutApp> {
  late final GoRouter _router;
  final _apiClient = createApiClient();
  final _tripDraft = TripDraft();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _refreshToken;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => OnboardingPage(
            onStart: () => context.go('/welcome'),
            onSignIn: () => context.go('/sign-in'),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => PhoneLoginPage(
            onRequestCode: _requestCode,
            onCodeSent: (phone) => context.push(
              '/sms-code?phone=${Uri.encodeQueryComponent(phone)}',
            ),
            onTermsPressed: () => context.push('/terms'),
            onPrivacyPressed: () => context.push('/privacy'),
          ),
        ),
        GoRoute(
          path: '/sms-code',
          builder: (context, state) {
            final phone = state.uri.queryParameters['phone'] ?? '';
            return SmsCodePage(
              phone: phone,
              onVerify: _verifyCode,
              onResend: _requestCode,
              onBack: () => context.pop(),
              onVerified: () => context.go('/profile-registration'),
            );
          },
        ),
        GoRoute(
          path: '/profile-registration',
          builder: (context, state) => ProfileRegistrationPage(
            onSave: _saveProfile,
            onCompleted: () => context.go('/city-selection'),
          ),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => const LegalDocumentPage.terms(),
        ),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => const LegalDocumentPage.privacy(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) =>
              WelcomePage(onContinue: () => context.go('/registration-intro')),
        ),
        GoRoute(
          path: '/registration-intro',
          builder: (context, state) => RegistrationIntroPage(
            onContinue: () => context.go('/role-selection'),
          ),
        ),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) => RoleSelectionPage(
            onRoleSelected: (_) => context.go('/city-selection'),
          ),
        ),
        GoRoute(
          path: '/city-selection',
          builder: (context, state) => const CitySelectionPage(),
        ),
        GoRoute(
          path: '/driver/profile',
          builder: (context, state) => DriverProfilePage(
            loadProfile: _loadProfile,
            loadUnreadNotifications: _loadUnreadNotifications,
            onOpen: (section) => section == ProfileSection.vehicles
                ? context.push('/driver/cars')
                : _comingSoon(),
            onLogout: _logout,
            onTab: (tab) => _openDriverTab(context, tab),
          ),
        ),
        GoRoute(
          path: '/driver/trips',
          builder: (context, state) => DriverTripsPage(
            loadTrips: _loadDriverTrips,
            onCreate: () => context.push('/driver/trips/new'),
            onTab: (tab) => _openDriverTab(context, tab),
            // The trip screen with requests comes next.
            onOpenTrip: (_) => _comingSoon(),
          ),
        ),
        GoRoute(
          path: '/driver/cars/new',
          builder: (context, state) => AddVehiclePage(
            loadBrands: _loadBrands,
            loadModels: _loadModels,
            pickPhoto: _pickPhoto,
            onSubmit: (vehicle) async {
              await _createVehicle(vehicle);
              if (context.mounted) context.pop();
            },
          ),
        ),
        GoRoute(
          path: '/driver/cars',
          builder: (context, state) => VehiclesPage(
            loadCars: _loadCars,
            // The "add a vehicle" form comes with its screens.
            onAddCar: () => context.push<void>('/driver/cars/new'),
            onOpenCar: (_) async => _comingSoon(),
          ),
        ),
        // Driver: "Новый заказ" wizard, six steps.
        GoRoute(
          path: '/driver/trips/new',
          builder: (context, state) => TripTypeStepPage(
            initialType: _tripDraft.vehicleType,
            onNext: (type) {
              _tripDraft.vehicleType = type;
              context.push('/driver/trips/new/route');
            },
          ),
        ),
        GoRoute(
          path: '/driver/trips/new/route',
          builder: (context, state) => RouteStepPage(
            draft: _tripDraft,
            loadCities: _loadCities,
            onNext: () => context.push('/driver/trips/new/prices'),
          ),
        ),
        GoRoute(
          path: '/driver/trips/new/prices',
          builder: (context, state) => PriceStepPage(
            draft: _tripDraft,
            onNext: () => context.push('/driver/trips/new/car'),
          ),
        ),
        GoRoute(
          path: '/driver/trips/new/car',
          builder: (context, state) => CarStepPage(
            draft: _tripDraft,
            loadCars: _loadCars,
            onNext: () => context.push('/driver/trips/new/extras'),
            onAddCar: () => context.push<void>('/driver/cars/new'),
          ),
        ),
        GoRoute(
          path: '/driver/trips/new/extras',
          builder: (context, state) => ExtrasStepPage(
            draft: _tripDraft,
            onNext: () => context.push('/driver/trips/new/booking'),
          ),
        ),
        GoRoute(
          path: '/driver/trips/new/booking',
          builder: (context, state) => BookingStepPage(
            draft: _tripDraft,
            onPublish: () => _createTrip(publish: true),
            onSaveTemplate: () => _createTrip(publish: false),
          ),
        ),
        GoRoute(
          path: '/driver/trips/published',
          redirect: (context, state) =>
              state.extra is DriverTrip ? null : '/driver/trips/new',
          builder: (context, state) {
            final trip = state.extra! as DriverTrip;
            return TripPublishedPage(
              trip: trip,
              loadLimits: _loadLimits,
              // "Мои поездки" screens come next; until then start a new trip.
              onMyTrips: () => context.go('/driver/trips'),
              onCreateReverse: trip.isReturnTrip
                  ? null
                  : () => context.push('/driver/trips/reverse', extra: trip),
            );
          },
        ),
        GoRoute(
          path: '/driver/trips/reverse',
          redirect: (context, state) =>
              state.extra is DriverTrip ? null : '/driver/trips/new',
          builder: (context, state) {
            final source = state.extra! as DriverTrip;
            return ReverseTripPage(
              source: source,
              onSubmit: (departure, arrival, {required publish}) =>
                  _createReverseTrip(
                    source,
                    departure,
                    arrival,
                    publish: publish,
                  ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close(force: true);
    _tripDraft.dispose();
    super.dispose();
  }

  Future<void> _requestCode(String phone) async {
    await _apiClient.post<void>(
      '/auth/request-code',
      data: <String, String>{'phone': phone},
    );
  }

  Future<void> _verifyCode(String phone, String code) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/verify',
      data: <String, String>{'phone': phone, 'code': code},
    );
    final accessToken = response.data?['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw StateError('Сервер не вернул токен доступа');
    }
    _apiClient.options.headers['Authorization'] = 'Bearer $accessToken';
    final refreshToken = response.data?['refresh_token'];
    _refreshToken = refreshToken is String ? refreshToken : null;
  }

  Future<List<City>> _loadCities() async {
    final response = await _apiClient.get<List<dynamic>>('/cities');
    return [
      for (final item in response.data ?? const [])
        City.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<DriverCar>> _loadCars() async {
    final response = await _apiClient.get<List<dynamic>>('/cars');
    return [
      for (final item in response.data ?? const [])
        DriverCar.fromJson(
          item as Map<String, dynamic>,
          mediaBaseUrl: AppConfig.apiBaseUrl,
        ),
    ];
  }

  /// Step 6: publishes the trip or saves it as a draft ("Сохранить шаблон",
  /// listed in "Мои поездки" → drafts), then starts the wizard over.
  Future<void> _createTrip({required bool publish}) async {
    final json = await _postJson(
      '/trips',
      _tripDraft.toCreateTripJson(publish: publish),
    );
    _tripDraft.reset();
    _afterCreate(DriverTrip.fromJson(json), publish: publish);
  }

  /// "Обратное направление": the backend mirrors [source] with a new time.
  Future<void> _createReverseTrip(
    DriverTrip source,
    DateTime departure,
    DateTime? arrival, {
    required bool publish,
  }) async {
    final json = await _postJson('/trips/${source.id}/reverse', {
      'departure_at': departure.toUtc().toIso8601String(),
      if (arrival != null) 'arrival_at': arrival.toUtc().toIso8601String(),
      'publish': publish,
    });
    _afterCreate(DriverTrip.fromJson(json), publish: publish);
  }

  /// Published → "Заказ опубликован!"; template → back to a new trip.
  void _afterCreate(DriverTrip trip, {required bool publish}) {
    if (publish) {
      _router.go('/driver/trips/published', extra: trip);
      return;
    }
    _router.go('/driver/trips/new');
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Шаблон сохранён в черновиках')),
    );
  }

  /// POST that turns the backend's error body into [DriverApiException].
  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return response.data!;
    } on DioException catch (e) {
      final error = e.response?.data;
      if (error is Map && error['message'] is String) {
        throw DriverApiException(
          error['message'] as String,
          code: error['code'] as String?,
          details: error['details'],
        );
      }
      rethrow;
    }
  }

  Future<DriverProfile> _loadProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/me');
    return DriverProfile.fromJson(
      response.data!,
      mediaBaseUrl: AppConfig.apiBaseUrl,
    );
  }

  Future<int> _loadUnreadNotifications() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    return response.data?['unread'] as int? ?? 0;
  }

  /// Revokes the refresh token (best effort) and forgets the session.
  Future<void> _logout() async {
    final refreshToken = _refreshToken;
    if (refreshToken != null) {
      try {
        await _apiClient.post<void>(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } on DioException {
        // Signing out locally still works without the network.
      }
    }
    _refreshToken = null;
    _apiClient.options.headers.remove('Authorization');
    _tripDraft.reset();
    _router.go('/sign-in');
  }

  /// Driver's bottom bar: "+", "Мои заказы" and "Профиль" have screens.
  void _openDriverTab(BuildContext context, DriverTab tab) {
    switch (tab) {
      case DriverTab.create:
        context.push('/driver/trips/new');
      case DriverTab.profile:
        context.go('/driver/profile');
      case DriverTab.orders:
        context.go('/driver/trips');
      case DriverTab.home || DriverTab.chats:
        _comingSoon();
    }
  }

  void _comingSoon() {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Раздел появится в следующей версии')),
      );
  }

  /// "Мои заказы": active trips with templates (drafts), or finished ones
  /// with cancelled.
  Future<List<DriverTrip>> _loadDriverTrips(DriverTripsTab tab) async {
    final statuses = tab == DriverTripsTab.active
        ? const ['active', 'draft']
        : const ['completed', 'cancelled'];
    final lists = await Future.wait([
      for (final status in statuses)
        _apiClient.get<List<dynamic>>(
          '/trips/mine',
          queryParameters: {'status': status},
        ),
    ]);
    return [
      for (final response in lists)
        for (final item in response.data ?? const [])
          DriverTrip.fromJson(
            item as Map<String, dynamic>,
            mediaBaseUrl: AppConfig.apiBaseUrl,
          ),
    ];
  }

  Future<List<CatalogItem>> _loadBrands() async {
    final response = await _apiClient.get<List<dynamic>>('/cars/brands');
    return [
      for (final item in response.data ?? const [])
        CatalogItem.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<CatalogItem>> _loadModels(int brandId) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/cars/brands/$brandId/models',
    );
    return [
      for (final item in response.data ?? const [])
        CatalogItem.fromJson(item as Map<String, dynamic>),
    ];
  }

  final _imagePicker = ImagePicker();

  Future<PickedPhoto?> _pickPhoto(PhotoSource source) async {
    final file = await _imagePicker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), fileName: file.name);
  }

  /// `POST /cars`, then the photo and the СТС. The car exists once the first
  /// call succeeds, so a failed upload is reported but does not undo it.
  Future<void> _createVehicle(NewVehicle vehicle) async {
    final car = await _postJson('/cars', vehicle.toJson());
    final id = car['id'] as String;
    var uploadsFailed = false;
    for (final (path, photo) in [
      ('/cars/$id/photo', vehicle.photo),
      ('/cars/$id/sts', vehicle.sts),
    ]) {
      if (photo == null) continue;
      try {
        await _apiClient.put<void>(
          path,
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              photo.bytes,
              filename: photo.fileName,
            ),
          }),
        );
      } on DioException {
        uploadsFailed = true;
      }
    }
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          uploadsFailed
              ? 'ТС добавлено, но фото не загрузилось — попробуйте позже'
              : 'ТС добавлено',
        ),
      ),
    );
  }

  Future<PublishLimits> _loadLimits(DateTime day) async {
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/trips/limits',
      queryParameters: {'date': date},
    );
    return PublishLimits.fromJson(response.data!);
  }

  Future<void> _saveProfile(String name, SelectedProfilePhoto photo) async {
    await _apiClient.patch<void>(
      '/me',
      data: <String, String>{'first_name': name},
    );
    await _apiClient.put<void>(
      '/me/avatar',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(photo.bytes, filename: photo.fileName),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Путь',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

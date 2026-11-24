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
import 'features/chat/domain/chat_models.dart';
import 'features/chat/presentation/chat_list_page.dart';
import 'features/chat/presentation/chat_page.dart';
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
import 'features/driver/presentation/trips/driver_trip_page.dart';
import 'features/driver/presentation/trips/driver_trips_page.dart';
import 'features/driver/presentation/trips/new_request_dialog.dart';
import 'features/driver/presentation/trips/passenger_profile_page.dart';
import 'features/driver/presentation/vehicles/add_vehicle_page.dart';
import 'features/driver/presentation/vehicles/catalog_picker_sheet.dart';
import 'features/driver/presentation/vehicles/vehicles_page.dart';
import 'features/driver/presentation/widgets/photo_source_sheet.dart';
import 'features/driver/presentation/widgets/success_toast.dart';
import 'features/driver/presentation/widgets/trip_edit_scope.dart';
import 'features/driver/presentation/widgets/driver_nav_bar.dart';
import 'features/onboarding/presentation/city_selection_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/onboarding/presentation/registration_intro_page.dart';
import 'features/onboarding/presentation/role_selection_page.dart';
import 'features/onboarding/presentation/welcome_page.dart';
import 'features/technical/presentation/technical_pages.dart';
import 'features/trips/domain/passenger_trip.dart';
import 'features/trips/domain/passenger_booking.dart';
import 'features/trips/domain/passenger_api_exception.dart';
import 'features/trips/domain/passenger_profile.dart';
import 'features/trips/presentation/passenger_booking_dialogs.dart';
import 'features/trips/presentation/passenger_booking_cancelled_page.dart';
import 'features/trips/presentation/passenger_booking_detail_page.dart';
import 'features/trips/presentation/passenger_booking_success_page.dart';
import 'features/trips/presentation/passenger_my_bookings_page.dart';
import 'features/trips/presentation/passenger_parcel_booking_sheet.dart';
import 'features/trips/presentation/passenger_personal_data_page.dart';
import 'features/trips/presentation/passenger_info_list_page.dart';
import 'features/trips/presentation/passenger_profile_page.dart';
import 'features/trips/presentation/passenger_role_page.dart';
import 'features/trips/presentation/passenger_account_blocked_page.dart';
import 'features/trips/presentation/passenger_trip_detail_page.dart';
import 'features/trips/presentation/passenger_trips_page.dart';
import 'features/trips/presentation/widgets/passenger_nav_bar.dart';

class PutApp extends StatefulWidget {
  const PutApp({super.key});

  @override
  State<PutApp> createState() => _PutAppState();
}

class _PutAppState extends State<PutApp> {
  late final GoRouter _router;
  final _apiClient = createApiClient();
  String? _pendingCity;
  TripRole? _pendingRole;
  final _tripDraft = TripDraft();

  /// "Изменение заказа": a copy of the trip being edited.
  final _editDraft = TripDraft();
  String? _editTripId;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _refreshToken;
  bool _verifiedUserIsNew = true;
  String _technicalReturnPath = '/passenger-trips';
  String? _blockedReason;
  DateTime? _blockedUntil;

  /// "Новый отклик": polls for booking requests while signed in.
  late final _requests = RequestWatcher(
    fetchUnread: _fetchRequestNotices,
    markRead: (id) => _apiClient.post<void>('/notifications/$id/read'),
    present: _presentRequest,
  );

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => OnboardingPage(
            onStart: () => context.go('/welcome'),
            onSignIn: () => context.go('/sign-in?mode=login'),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (context, state) {
            final mode = state.uri.queryParameters['mode'] ?? 'login';
            return PhoneLoginPage(
              onRequestCode: _requestCode,
              onCodeSent: (phone) => context.push(
                '/sms-code?phone=${Uri.encodeQueryComponent(phone)}&mode=$mode',
              ),
              onTermsPressed: () => context.push('/terms'),
              onPrivacyPressed: () => context.push('/privacy'),
            );
          },
        ),
        GoRoute(
          path: '/sms-code',
          builder: (context, state) {
            final phone = state.uri.queryParameters['phone'] ?? '';
            final isRegistration =
                state.uri.queryParameters['mode'] == 'register';
            return SmsCodePage(
              phone: phone,
              onVerify: (phone, code) =>
                  _verifyCode(phone, code, isRegistration: isRegistration),
              onResend: _requestCode,
              onBack: () => context.pop(),
              onVerified: () => _continueAfterVerification(context),
            );
          },
        ),
        GoRoute(
          path: '/profile-registration',
          builder: (context, state) => ProfileRegistrationPage(
            onSave: _saveProfile,
            onCompleted: () async {
              final city = _pendingCity;
              if (city == null) {
                context.go('/city-selection');
                return;
              }
              await _saveCity(city);
              if (context.mounted) context.go(_onboardingDestination);
            },
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
            onRoleSelected: (role) {
              _pendingRole = role;
              context.go('/city-selection');
            },
          ),
        ),
        GoRoute(
          path: '/city-selection',
          builder: (context, state) => CitySelectionPage(
            loadCities: _loadCityNames,
            onCitySelected: (city) async {
              _pendingCity = city;
              if (!_apiClient.options.headers.containsKey('Authorization')) {
                context.go('/sign-in?mode=register');
                return;
              }
              await _saveCity(city);
              if (context.mounted) context.go(_onboardingDestination);
            },
          ),
        ),
        GoRoute(
          path: '/passenger-trips',
          builder: (context, state) => PassengerTripsPage(
            loadTrips: _loadPassengerTrips,
            onTripPressed: (trip) =>
                context.push('/passenger-trips/${trip.id}'),
            onOrdersPressed: () => context.go('/passenger-bookings'),
            onChatsPressed: () =>
                _openPassengerTab(context, PassengerNavTab.chats),
            onProfilePressed: () => context.go('/passenger-profile'),
          ),
          routes: [
            GoRoute(
              path: ':tripId',
              builder: (context, state) {
                final tripId = state.pathParameters['tripId'] ?? '';
                final booking = state.extra is PassengerBooking
                    ? state.extra! as PassengerBooking
                    : null;
                return PassengerTripDetailPage(
                  loadDetails: () => _loadPassengerTripDetails(tripId),
                  booking: booking,
                  onBack: () => context.pop(),
                  onBookSeat: (draft) => _createSeatBooking(context, draft),
                  onSendParcel: (draft) => _createParcelBooking(context, draft),
                  onCancelBooking: booking == null
                      ? null
                      : () => _requestBookingCancel(context, booking),
                  onMessageDriver: booking == null
                      ? null
                      : () => _openChatForBooking(context, booking.id),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/passenger-bookings',
          builder: (context, state) => PassengerMyBookingsPage(
            loadBookings: _loadPassengerBookings,
            onBookingPressed: (booking) async {
              await context.push('/passenger-bookings/${booking.id}');
            },
            onTrips: () => context.go('/passenger-trips'),
            onChats: () => _openPassengerTab(context, PassengerNavTab.chats),
            onProfile: () => context.go('/passenger-profile'),
          ),
          routes: [
            GoRoute(
              path: ':bookingId',
              builder: (context, state) {
                final bookingId = state.pathParameters['bookingId'] ?? '';
                return PassengerBookingDetailPage(
                  loadBooking: () => _loadPassengerBooking(bookingId),
                  onBack: () => context.pop(),
                  onCancel: (booking) =>
                      _requestBookingCancel(context, booking),
                  onPay: (booking) => _payBooking(context, booking),
                  onMessageDriver: () =>
                      _openChatForBooking(context, bookingId),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/booking-success',
          builder: (context, state) {
            final booking = state.extra! as PassengerBooking;
            return PassengerBookingSuccessPage(
              onMyTrips: () => context.go('/passenger-bookings/${booking.id}'),
              onMessageDriver: () => _openChatForBooking(context, booking.id),
            );
          },
        ),
        GoRoute(
          path: '/passenger-profile',
          builder: (context, state) => PassengerProfilePage(
            loadProfile: _loadPassengerProfile,
            loadUnreadNotifications: _loadUnreadNotifications,
            onOpen: (section) => _openPassengerProfileSection(context, section),
            onLogout: _logout,
            onTrips: () => context.go('/passenger-trips'),
            onOrders: () => context.go('/passenger-bookings'),
            onChats: () => _openPassengerTab(context, PassengerNavTab.chats),
          ),
          routes: [
            GoRoute(
              path: 'role',
              builder: (context, state) => PassengerRolePage(
                onBack: () => context.pop(),
                onDriver: () {
                  _pendingRole = TripRole.driver;
                  context.go('/driver/trips');
                },
              ),
            ),
            GoRoute(
              path: 'personal',
              builder: (context, state) => PassengerPersonalDataPage(
                loadProfile: _loadPassengerProfile,
                pickPhoto: _pickPhoto,
                onSave: _savePassengerProfile,
                onBack: () => context.pop(),
              ),
            ),
            GoRoute(
              path: 'complaints',
              builder: (context, state) => PassengerInfoListPage(
                title: 'Жалобы',
                emptyMessage: 'У вас нет жалоб',
                loadItems: _loadPassengerComplaints,
                onBack: () => context.pop(),
              ),
            ),
            GoRoute(
              path: 'notifications',
              builder: (context, state) => PassengerInfoListPage(
                title: 'Уведомления',
                emptyMessage: 'У вас нет уведомлений',
                loadItems: _loadPassengerNotifications,
                onBack: () => context.pop(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/booking-cancelled',
          redirect: (context, state) =>
              state.extra is PassengerBooking ? null : '/passenger-bookings',
          builder: (context, state) => PassengerBookingCancelledPage(
            booking: state.extra! as PassengerBooking,
            onHome: () => context.go('/passenger-trips'),
          ),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) {
            final driverMode = _pendingRole == TripRole.driver;
            return ChatListPage(
              loadChats: _loadChats,
              onOpenChat: (chat) => context.push('/chats/${chat.id}'),
              onBack: () =>
                  context.go(driverMode ? '/driver/trips' : '/passenger-trips'),
              bottomNavigationBar: driverMode
                  ? DriverNavBar(
                      current: DriverTab.chats,
                      onSelect: (tab) => _openDriverTab(context, tab),
                    )
                  : PassengerNavBar(
                      current: PassengerNavTab.chats,
                      onSelect: (tab) => _openPassengerTab(context, tab),
                    ),
            );
          },
          routes: [
            GoRoute(
              path: ':chatId',
              builder: (context, state) {
                final chatId = state.pathParameters['chatId'] ?? '';
                return ChatPage(
                  loadChat: () => _loadChat(chatId),
                  loadMessages: () => _loadChatMessages(chatId),
                  sendMessage: (text) => _sendChatMessage(chatId, text),
                  markRead: () => _markChatRead(chatId),
                  onBack: () => context.pop(),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/account-blocked',
          builder: (context, state) {
            final sanction = state.extra is PassengerCancellationInfo
                ? state.extra! as PassengerCancellationInfo
                : null;
            return PassengerAccountBlockedPage(
              reason: sanction?.warning,
              blockedUntil: sanction?.blockedUntil,
              onAcknowledged: () => context.go('/passenger-trips'),
            );
          },
        ),
        GoRoute(
          path: '/loading',
          builder: (context, state) => const TechnicalLoadingPage(),
        ),
        GoRoute(
          path: '/no-internet',
          builder: (context, state) =>
              TechnicalOfflinePage(onRetry: _retryTechnicalRoute),
        ),
        GoRoute(
          path: '/technical-error',
          builder: (context, state) =>
              TechnicalErrorPage(onRetry: _retryTechnicalRoute),
        ),
        GoRoute(
          path: '/account-access-blocked',
          builder: (context, state) => TechnicalAccountBlockedPage(
            reason: _blockedReason,
            blockedUntil: _blockedUntil,
          ),
        ),
        GoRoute(
          path: '/driver/profile',
          builder: (context, state) => DriverProfilePage(
            loadProfile: _loadProfile,
            loadUnreadNotifications: _loadUnreadNotifications,
            onOpen: (section) {
              if (section == ProfileSection.passengerMode) {
                _pendingRole = TripRole.passenger;
                context.go('/passenger-profile');
              } else if (section == ProfileSection.vehicles) {
                context.push('/driver/cars');
              } else {
                _comingSoon();
              }
            },
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
            onOpenTrip: (trip) => context.push<bool>('/driver/trip/${trip.id}'),
          ),
        ),
        GoRoute(
          path: '/driver/trip/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DriverTripPage(
              load: () => _loadTripWithBookings(id),
              openBookingId: state.uri.queryParameters['booking'],
              confirmBooking: (bookingId) => _guard(
                () => _apiClient.post<void>('/bookings/$bookingId/confirm'),
              ),
              rejectBooking: (bookingId) => _guard(
                () => _apiClient.post<void>('/bookings/$bookingId/reject'),
              ),
              loadCancelPreview: _loadCancelPreview,
              cancelTrip: (tripId) async {
                await _guard(
                  () => _apiClient.post<void>('/trips/$tripId/cancel'),
                );
                _snack('Поездка отменена');
              },
              deleteDraft: (tripId) async {
                await _guard(() => _apiClient.delete<void>('/trips/$tripId'));
                _snack('Шаблон удалён');
              },
              changeSeats: (tripId, seats) => _guard(
                () => _apiClient.patch<void>(
                  '/trips/$tripId/seats',
                  data: {'seats_total': seats},
                ),
              ),
              setAcceptingBookings: (tripId, accepting) => _guard(
                () => _apiClient.post<void>(
                  accepting
                      ? '/trips/$tripId/open-booking'
                      : '/trips/$tripId/close-booking',
                ),
              ),
              // Transferring passengers needs its own screens and rules.
              onTransferPassengers: (_) => _comingSoon(),
              onEdit: (trip) {
                _editDraft.loadTrip(trip);
                _editTripId = trip.id;
                // As in the design: editing opens on the route ("Шаг 2 из 4").
                context.push('/driver/edit/route');
              },
              onOpenBooking: (booking) =>
                  context.push<bool>('/driver/booking', extra: booking),
              onOpenDriver: () => context.go('/driver/profile'),
            );
          },
        ),
        GoRoute(
          path: '/driver/booking',
          redirect: (context, state) =>
              state.extra is TripBooking ? null : '/driver/trips',
          builder: (context, state) => TripPassengerProfilePage(
            booking: state.extra! as TripBooking,
            // The chat screen comes with the "Чаты" section.
            onChat: _comingSoon,
          ),
        ),
        // "Изменение заказа": the wizard steps in edit mode (TripEditScope).
        GoRoute(
          path: '/driver/edit/route',
          builder: (context, state) => _editScope(
            RouteStepPage(
              draft: _editDraft,
              loadCities: _loadCities,
              onNext: () => context.push('/driver/edit/car'),
            ),
          ),
        ),
        GoRoute(
          path: '/driver/edit/prices',
          builder: (context, state) => _editScope(
            PriceStepPage(draft: _editDraft, onNext: () => context.pop()),
          ),
        ),
        GoRoute(
          path: '/driver/edit/car',
          builder: (context, state) => _editScope(
            CarStepPage(
              draft: _editDraft,
              loadCars: _loadCars,
              onNext: () => context.push('/driver/edit/extras'),
              onAddCar: () => context.push<void>('/driver/cars/new'),
            ),
          ),
        ),
        GoRoute(
          path: '/driver/edit/extras',
          builder: (context, state) =>
              _editScope(ExtrasStepPage(draft: _editDraft, onNext: () {})),
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
      errorBuilder: (context, state) =>
          TechnicalErrorPage(onRetry: () => context.go('/passenger-trips')),
    );
    _apiClient.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final technicalRoute = _technicalRouteFor(error);
          if (technicalRoute != null) {
            _openTechnicalRoute(technicalRoute);
          }
          handler.next(error);
        },
      ),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close(force: true);
    _tripDraft.dispose();
    _editDraft.dispose();
    _requests.stop();
    super.dispose();
  }

  Future<void> _requestCode(String phone) async {
    await _apiClient.post<void>(
      '/auth/request-code',
      data: <String, String>{'phone': phone},
    );
  }

  String get _onboardingDestination =>
      _pendingRole == TripRole.driver ? '/driver/trips' : '/passenger-trips';

  Future<void> _verifyCode(
    String phone,
    String code, {
    required bool isRegistration,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/verify',
      data: <String, String>{'phone': phone, 'code': code},
    );
    final isNewUser = response.data?['is_new_user'] != false;
    final refreshToken = response.data?['refresh_token'];
    if (isRegistration && !isNewUser) {
      if (refreshToken is String && refreshToken.isNotEmpty) {
        try {
          await _apiClient.post<void>(
            '/auth/logout',
            data: {'refresh_token': refreshToken},
          );
        } on DioException {
          // Токен всё равно не сохраняется на устройстве.
        }
      }
      throw const SmsVerificationException(
        'Аккаунт с таким телефоном уже существует',
      );
    }
    final accessToken = response.data?['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw StateError('Сервер не вернул токен доступа');
    }
    _apiClient.options.headers['Authorization'] = 'Bearer $accessToken';
    _refreshToken = refreshToken is String ? refreshToken : null;
    _verifiedUserIsNew = isNewUser;
    _requests.start();
  }

  Future<void> _continueAfterVerification(BuildContext context) async {
    if (_verifiedUserIsNew) {
      context.go('/profile-registration');
      return;
    }
    try {
      final city = _pendingCity;
      if (city != null) await _saveCity(city);
      if (context.mounted) context.go(_onboardingDestination);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _passengerErrorMessage(error, 'Не удалось завершить вход'),
          ),
        ),
      );
    }
  }

  Future<List<City>> _loadCities() async {
    final response = await _apiClient.get<List<dynamic>>('/cities');
    return [
      for (final item in response.data ?? const [])
        City.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<String>> _loadCityNames() async =>
      (await _loadCities()).map((city) => city.name).toList(growable: false);

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

  Future<PassengerProfile> _loadPassengerProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/me');
      final data = response.data;
      if (data == null) throw StateError('Профиль не найден');
      return PassengerProfile.fromJson(
        data,
        mediaBaseUrl: AppConfig.apiBaseUrl,
      );
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить профиль'),
      );
    }
  }

  Future<int> _loadUnreadNotifications() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    return response.data?['unread'] as int? ?? 0;
  }

  Future<List<AppChat>> _loadChats() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/chats');
      return (response.data ?? const [])
          .whereType<Map>()
          .map(
            (item) => AppChat.fromJson(
              item.cast<String, dynamic>(),
              mediaBaseUrl: AppConfig.apiBaseUrl,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить чаты'),
      );
    }
  }

  Future<AppChat> _loadChat(String chatId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/chats/$chatId',
      );
      final data = response.data;
      if (data == null) throw StateError('Чат не найден');
      return AppChat.fromJson(data, mediaBaseUrl: AppConfig.apiBaseUrl);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить чат'),
      );
    }
  }

  Future<List<AppChatMessage>> _loadChatMessages(String chatId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/chats/$chatId/messages',
      );
      return (response.data ?? const [])
          .whereType<Map>()
          .map((item) => AppChatMessage.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить сообщения'),
      );
    }
  }

  Future<AppChatMessage> _sendChatMessage(String chatId, String text) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/chats/$chatId/messages',
        data: {'text': text},
      );
      final data = response.data;
      if (data == null) throw StateError('Сообщение не отправлено');
      return AppChatMessage.fromJson(data);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось отправить сообщение'),
      );
    }
  }

  Future<void> _markChatRead(String chatId) async {
    try {
      await _apiClient.post<void>('/chats/$chatId/read');
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось отметить сообщения'),
      );
    }
  }

  Future<void> _openChatForBooking(
    BuildContext context,
    String bookingId,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/chats',
        data: {'booking_id': bookingId},
      );
      final data = response.data;
      if (data == null) throw StateError('Чат не найден');
      final chat = AppChat.fromJson(data, mediaBaseUrl: AppConfig.apiBaseUrl);
      if (context.mounted) context.push('/chats/${chat.id}');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PassengerApiException
                ? error.message
                : _passengerErrorMessage(error, 'Не удалось открыть чат'),
          ),
        ),
      );
    }
  }

  Future<List<PassengerInfoItem>> _loadPassengerComplaints() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/me/complaints');
      return (response.data ?? const [])
          .whereType<Map>()
          .map((raw) {
            final item = raw.cast<String, dynamic>();
            final text = item['text'] as String?;
            return PassengerInfoItem(
              id: item['id']?.toString() ?? '',
              title: _complaintReason(item['reason']?.toString() ?? ''),
              body: text == null || text.trim().isEmpty
                  ? 'Статус: ${item['status'] ?? 'получена'}'
                  : text,
              createdAt: DateTime.tryParse(
                item['created_at']?.toString() ?? '',
              ),
            );
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить жалобы'),
      );
    }
  }

  Future<List<PassengerInfoItem>> _loadPassengerNotifications() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/notifications');
      return (response.data ?? const [])
          .whereType<Map>()
          .map((raw) {
            final item = raw.cast<String, dynamic>();
            return PassengerInfoItem(
              id: item['id']?.toString() ?? '',
              title: item['title'] as String? ?? 'Уведомление',
              body: item['body'] as String? ?? '',
              createdAt: DateTime.tryParse(
                item['created_at']?.toString() ?? '',
              ),
              isRead: item['is_read'] == true,
            );
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить уведомления'),
      );
    }
  }

  String _complaintReason(String value) => switch (value) {
    'rude_behavior' => 'Грубое поведение',
    'unsafe_driving' => 'Опасное вождение',
    'no_show' => 'Участник не явился',
    'fraud' => 'Мошенничество',
    _ => 'Жалоба',
  };

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
    _requests.stop();
    _refreshToken = null;
    _apiClient.options.headers.remove('Authorization');
    _tripDraft.reset();
    _router.go('/sign-in');
  }

  /// Driver's bottom bar: "+", "Мои заказы" and "Профиль" have screens.
  void _openDriverTab(BuildContext context, DriverTab tab) {
    _pendingRole = TripRole.driver;
    switch (tab) {
      case DriverTab.create:
        context.push('/driver/trips/new');
      case DriverTab.profile:
        context.go('/driver/profile');
      case DriverTab.orders:
        context.go('/driver/trips');
      case DriverTab.chats:
        context.go('/chats');
      // "Поездки" comes with its screen.
      case DriverTab.trips:
        _comingSoon();
    }
  }

  void _openPassengerTab(BuildContext context, PassengerNavTab tab) {
    _pendingRole = TripRole.passenger;
    switch (tab) {
      case PassengerNavTab.trips:
        context.go('/passenger-trips');
      case PassengerNavTab.orders:
        context.go('/passenger-bookings');
      case PassengerNavTab.chats:
        context.go('/chats');
      case PassengerNavTab.profile:
        context.go('/passenger-profile');
    }
  }

  void _comingSoon() {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Раздел появится в следующей версии')),
      );
  }

  String? _technicalRouteFor(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['code'] == 'user_blocked') {
      _blockedReason = data['message'] as String?;
      final details = data['details'];
      final rawBlockedUntil = details is Map
          ? details['blocked_until']
          : data['blocked_until'];
      _blockedUntil = DateTime.tryParse(rawBlockedUntil?.toString() ?? '');
      return '/account-access-blocked';
    }
    final status = error.response?.statusCode;
    if (status != null && status >= 500) {
      return '/technical-error';
    }
    if (error.response == null ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '/no-internet';
    }
    return null;
  }

  void _openTechnicalRoute(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _router.routerDelegate.currentConfiguration.uri.path;
      const technicalPaths = {
        '/loading',
        '/no-internet',
        '/technical-error',
        '/account-access-blocked',
      };
      if (!technicalPaths.contains(current)) {
        _technicalReturnPath = current.isEmpty ? '/passenger-trips' : current;
      }
      if (current != route) _router.go(route);
    });
  }

  Future<void> _retryTechnicalRoute() async {
    final destination = _technicalReturnPath;
    _router.go('/loading');
    try {
      await _apiClient.get<void>('/health');
      if (mounted) _router.go(destination);
    } on DioException catch (error) {
      if (!mounted) return;
      _router.go(_technicalRouteFor(error) ?? '/technical-error');
    }
  }

  void _openPassengerProfileSection(
    BuildContext context,
    PassengerProfileSection section,
  ) {
    switch (section) {
      case PassengerProfileSection.role:
        context.push('/passenger-profile/role');
      case PassengerProfileSection.personal:
        context.push('/passenger-profile/personal');
      case PassengerProfileSection.complaints:
        context.push('/passenger-profile/complaints');
      case PassengerProfileSection.notifications:
        context.push('/passenger-profile/notifications');
      case PassengerProfileSection.savedRoutes ||
          PassengerProfileSection.history ||
          PassengerProfileSection.payment ||
          PassengerProfileSection.faq ||
          PassengerProfileSection.about:
        _showComingSoon(context, 'Раздел');
    }
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

  Future<TripWithBookings> _loadTripWithBookings(String id) async {
    final responses = await Future.wait([
      _apiClient.get<Map<String, dynamic>>('/trips/$id'),
      _apiClient.get<List<dynamic>>('/trips/$id/bookings'),
    ]);
    return (
      trip: DriverTrip.fromJson(
        responses[0].data! as Map<String, dynamic>,
        mediaBaseUrl: AppConfig.apiBaseUrl,
      ),
      bookings: [
        for (final item in (responses[1].data as List?) ?? const [])
          TripBooking.fromJson(
            item as Map<String, dynamic>,
            mediaBaseUrl: AppConfig.apiBaseUrl,
          ),
      ],
    );
  }

  Future<CancelPreview> _loadCancelPreview(String tripId) async {
    final response = await _guard(
      () =>
          _apiClient.get<Map<String, dynamic>>('/trips/$tripId/cancel-preview'),
    );
    return CancelPreview.fromJson(response.data!);
  }

  /// Runs an API call, turning the backend's error body into
  /// [DriverApiException].
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
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

  Widget _editScope(Widget page) => TripEditScope(
    canSave: () => _editDraft.isDirty && _editDraft.isComplete(DateTime.now()),
    onSave: _saveEdit,
    onEditPrices: () => _router.push('/driver/edit/prices'),
    child: page,
  );

  /// `PUT /trips/{id}`, then back to "Мои заказы" with a green note.
  Future<void> _saveEdit() async {
    final id = _editTripId!;
    await _guard(
      () => _apiClient.put<void>('/trips/$id', data: _editDraft.toWriteJson()),
    );
    _router.go('/driver/trips');
    showSuccessToast(_messengerKey.currentState, 'Изменения сохранены');
  }

  void _snack(String text) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<List<RequestNotice>> _fetchRequestNotices() async {
    final response = await _apiClient.get<List<dynamic>>(
      '/notifications',
      queryParameters: {'unread_only': true, 'limit': 20},
    );
    return [
      for (final item in response.data ?? const [])
        if (DriverEvent.parse((item as Map)['type']) case final event?)
          RequestNotice(
            id: item['id'] as String,
            tripId: item['trip_id'] as String?,
            bookingId: item['booking_id'] as String?,
            event: event,
          ),
    ];
  }

  Future<void> _presentRequest(RequestNotice notice) async {
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || notice.tripId == null) return;
    final trip = '/driver/trip/${notice.tripId}';
    switch (notice.event) {
      case DriverEvent.request:
        if (!await showNewRequestDialog(context)) return;
        final booking = notice.bookingId;
        _router.push(booking == null ? trip : '$trip?booking=$booking');
      case DriverEvent.paid:
        if (await showPaidDialog(context)) _router.push(trip);
    }
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

  Future<void> _savePassengerProfile(
    String firstName,
    String? lastName,
    PickedPhoto? photo,
  ) async {
    try {
      await _apiClient.patch<void>(
        '/me',
        data: <String, String?>{'first_name': firstName, 'last_name': lastName},
      );
      if (photo != null) {
        await _apiClient.put<void>(
          '/me/avatar',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              photo.bytes,
              filename: photo.fileName,
            ),
          }),
        );
      }
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось сохранить данные'),
      );
    }
  }

  Future<void> _saveCity(String city) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/cities',
      queryParameters: <String, String>{'query': city},
    );
    final cities = response.data ?? const [];
    final normalizedCity = foldName(city.trim());
    final exact = cities
        .whereType<Map>()
        .cast<Map<dynamic, dynamic>>()
        .firstWhere(
          (item) =>
              foldName(item['name']?.toString().trim() ?? '') == normalizedCity,
          orElse: () => <dynamic, dynamic>{},
        );
    final id = exact['id'];
    if (id is! num) {
      throw const PassengerApiException(
        'Выбранный город больше недоступен. Выберите другой город.',
      );
    }
    await _apiClient.patch<void>(
      '/me',
      data: <String, int>{'city_id': id.toInt()},
    );
  }

  Future<List<PassengerTrip>> _loadPassengerTrips(
    String type,
    PassengerTripFilter filter,
  ) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/search/trips',
      queryParameters: filter.toQueryParameters(type),
    );
    return (response.data?['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => PassengerTrip.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<PassengerTripDetails> _loadPassengerTripDetails(String tripId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/trips/$tripId',
    );
    final data = response.data;
    if (data == null) throw StateError('Поездка не найдена');
    return PassengerTripDetails.fromJson(data);
  }

  Future<List<PassengerBooking>> _loadPassengerBookings() async {
    try {
      final response = await _apiClient.get<List<dynamic>>('/bookings/mine');
      return (response.data ?? const [])
          .whereType<Map>()
          .map(
            (item) => PassengerBooking.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить заказы'),
      );
    }
  }

  Future<PassengerBooking> _loadPassengerBooking(String bookingId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/bookings/$bookingId',
      );
      final data = response.data;
      if (data == null) throw StateError('Бронирование не найдено');
      return PassengerBooking.fromJson(data);
    } on DioException catch (error) {
      throw PassengerApiException(
        _passengerErrorMessage(error, 'Не удалось загрузить бронирование'),
      );
    }
  }

  Future<void> _createSeatBooking(
    BuildContext context,
    PassengerSeatBookingDraft draft,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/bookings',
      data: draft.toJson(),
    );
    final data = response.data;
    if (data == null) throw StateError('Сервер не вернул бронирование');
    final booking = PassengerBooking.fromJson(data);
    if (!context.mounted) return;
    await _handleBookingStatus(context, booking);
  }

  Future<void> _createParcelBooking(
    BuildContext context,
    PassengerParcelBookingDraft draft,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/bookings',
      data: draft.toJson(),
    );
    final data = response.data;
    if (data == null) throw StateError('Сервер не вернул бронирование');
    final booking = PassengerBooking.fromJson(data);
    if (!context.mounted) return;
    await _handleBookingStatus(context, booking);
  }

  Future<void> _handleBookingStatus(
    BuildContext context,
    PassengerBooking booking,
  ) async {
    switch (booking.status) {
      case 'awaiting_payment':
        await showBookingAcceptedDialog(
          context,
          onPay: () => _payBooking(context, booking),
          onCancel: () => _requestBookingCancel(context, booking),
        );
      case 'rejected':
        await showBookingRejectedDialog(context);
      case 'paid':
      case 'completed':
        if (context.mounted) {
          context.push('/booking-success', extra: booking);
        }
      default:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Заявка отправлена водителю')),
          );
    }
  }

  Future<void> _payBooking(
    BuildContext context,
    PassengerBooking booking,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/bookings/${booking.id}/pay',
      );
      final data = response.data;
      if (data == null) throw StateError('Сервер не подтвердил оплату');
      final paid = PassengerBooking.fromJson(data);
      if (context.mounted) context.push('/booking-success', extra: paid);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _passengerErrorMessage(error, 'Не удалось выполнить оплату'),
          ),
        ),
      );
    }
  }

  Future<void> _requestBookingCancel(
    BuildContext context,
    PassengerBooking booking,
  ) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/bookings/${booking.id}/cancel-preview',
      );
      final data = response.data;
      if (data == null) throw StateError('Сервер не вернул условия отмены');
      final preview = PassengerCancellationInfo.fromJson(data);
      if (!context.mounted) return;
      await showBookingCancellationDialog(
        context,
        preview: preview,
        booking: booking,
        onConfirm: () => _cancelBooking(context, booking),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _passengerErrorMessage(
              error,
              'Не удалось проверить условия отмены',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _cancelBooking(
    BuildContext context,
    PassengerBooking booking,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/bookings/${booking.id}/cancel',
      );
      final data = response.data;
      if (data == null) throw StateError('Сервер не подтвердил отмену');
      final result = PassengerCancellationResult.fromJson(data);
      if (!context.mounted) return;
      if (result.sanction.blocksAccount) {
        context.go('/account-blocked', extra: result.sanction);
        return;
      }
      context.go('/booking-cancelled', extra: result.booking);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _passengerErrorMessage(error, 'Не удалось отменить бронирование'),
          ),
        ),
      );
    }
  }

  String _passengerErrorMessage(Object error, String fallback) {
    if (error is PassengerApiException) return error.message;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    }
    return fallback;
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature — следующий экран')));
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

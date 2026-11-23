import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/legal_document_page.dart';
import 'features/auth/presentation/phone_login_page.dart';
import 'features/auth/presentation/profile_registration_page.dart';
import 'features/auth/presentation/sms_code_page.dart';
import 'features/onboarding/presentation/city_selection_page.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/onboarding/presentation/registration_intro_page.dart';
import 'features/onboarding/presentation/role_selection_page.dart';
import 'features/onboarding/presentation/welcome_page.dart';
import 'features/trips/domain/passenger_trip.dart';
import 'features/trips/domain/passenger_booking.dart';
import 'features/trips/presentation/passenger_booking_dialogs.dart';
import 'features/trips/presentation/passenger_booking_success_page.dart';
import 'features/trips/presentation/passenger_account_blocked_page.dart';
import 'features/trips/presentation/passenger_address_search_sheet.dart';
import 'features/trips/presentation/passenger_trip_detail_page.dart';
import 'features/trips/presentation/passenger_trips_page.dart';

class PutApp extends StatefulWidget {
  const PutApp({super.key});

  @override
  State<PutApp> createState() => _PutAppState();
}

class _PutAppState extends State<PutApp> {
  late final GoRouter _router;
  final _apiClient = createApiClient();
  String? _pendingCity;

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
            onCompleted: () async {
              final city = _pendingCity;
              if (city == null) {
                context.go('/city-selection');
                return;
              }
              await _saveCity(city);
              if (context.mounted) context.go('/passenger-trips');
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
            onRoleSelected: (_) => context.go('/city-selection'),
          ),
        ),
        GoRoute(
          path: '/city-selection',
          builder: (context, state) => CitySelectionPage(
            onCitySelected: (city) async {
              _pendingCity = city;
              if (!_apiClient.options.headers.containsKey('Authorization')) {
                context.go('/sign-in');
                return;
              }
              await _saveCity(city);
              if (context.mounted) context.go('/passenger-trips');
            },
          ),
        ),
        GoRoute(
          path: '/passenger-trips',
          builder: (context, state) => PassengerTripsPage(
            loadTrips: _loadPassengerTrips,
            onTripPressed: (trip) =>
                context.push('/passenger-trips/${trip.id}'),
            onCreatePressed: () => _startTripCreation(context),
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
                  onSendParcel: () =>
                      _showComingSoon(context, 'Оплата отправки'),
                  onCancelBooking: booking == null
                      ? null
                      : () => _requestBookingCancel(context, booking),
                  onMessageDriver: () =>
                      _showComingSoon(context, 'Чат с водителем'),
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
              onMyTrips: () => context.go(
                '/passenger-trips/${booking.tripId}',
                extra: booking,
              ),
              onMessageDriver: () =>
                  _showComingSoon(context, 'Чат с водителем'),
            );
          },
        ),
        GoRoute(
          path: '/account-blocked',
          builder: (context, state) => PassengerAccountBlockedPage(
            onAcknowledged: () => context.go('/passenger-trips'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close(force: true);
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

  Future<void> _saveCity(String city) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/cities',
      queryParameters: <String, String>{'query': city},
    );
    final cities = response.data ?? const [];
    final exact = cities
        .whereType<Map>()
        .cast<Map<dynamic, dynamic>>()
        .firstWhere(
          (item) => item['name'] == city,
          orElse: () => <dynamic, dynamic>{},
        );
    final id = exact['id'];
    if (id is! int) throw StateError('Город не найден');
    await _apiClient.patch<void>('/me', data: <String, int>{'city_id': id});
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

  Future<void> _startTripCreation(BuildContext context) async {
    final address = await showPassengerAddressSearchSheet(context);
    if (!context.mounted || address == null) return;
    _showComingSoon(context, 'Маршрут от «${address.title}»');
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
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выполнить оплату')),
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
        onConfirm: () => _cancelBooking(context, booking),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось проверить условия отмены')),
      );
    }
  }

  Future<void> _cancelBooking(
    BuildContext context,
    PassengerBooking booking,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/bookings/${booking.id}/cancel',
    );
    final data = response.data;
    if (data == null) throw StateError('Сервер не подтвердил отмену');
    final result = PassengerCancellationResult.fromJson(data);
    if (!context.mounted) return;
    if (result.sanction.blocksAccount) {
      context.go('/account-blocked');
      return;
    }
    context.go('/passenger-trips');
    final message = result.booking.isRefunded
        ? 'Бронирование отменено. Комиссия возвращена'
        : 'Бронирование отменено';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

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

class PutApp extends StatefulWidget {
  const PutApp({super.key});

  @override
  State<PutApp> createState() => _PutAppState();
}

class _PutAppState extends State<PutApp> {
  late final GoRouter _router;
  final _apiClient = createApiClient();

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

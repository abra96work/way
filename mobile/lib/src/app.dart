import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              OnboardingPage(onStart: () => context.go('/welcome')),
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
          builder: (context, state) => const RoleSelectionPage(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
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

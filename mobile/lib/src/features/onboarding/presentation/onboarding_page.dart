import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, this.onStart, this.onSignIn});

  static const backgroundColor = Color(0xFF1DB954);

  final VoidCallback? onStart;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final responsiveLogoSize = (constraints.maxHeight * 0.42)
                  .clamp(190.0, 299.0)
                  .toDouble();
              final logoSize = math.min(
                responsiveLogoSize,
                constraints.maxWidth - 32,
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: [
                            SizedBox(
                              height: math.min(
                                40,
                                constraints.maxHeight * 0.055,
                              ),
                            ),
                            Image.asset(
                              'assets/images/logo_marker.png',
                              key: const ValueKey('onboarding-logo'),
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.contain,
                              semanticLabel: 'Логотип приложения Путь',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Путь',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                height: 0.88,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Попутчики и посылки по вашему маршруту',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFF3F3F3),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          _OnboardingButton(
                            key: const ValueKey('onboarding-start'),
                            label: 'Начать',
                            filled: true,
                            onPressed:
                                onStart ??
                                () => _showPendingFlow(
                                  context,
                                  'Регистрация появится на следующем шаге',
                                ),
                          ),
                          const SizedBox(height: 12),
                          _OnboardingButton(
                            key: const ValueKey('onboarding-sign-in'),
                            label: 'Уже есть аккаунт',
                            onPressed:
                                onSignIn ??
                                () => _showPendingFlow(
                                  context,
                                  'Вход появится на следующем шаге',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static void _showPendingFlow(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          backgroundColor: WidgetStatePropertyAll(
            filled ? Colors.white : Colors.transparent,
          ),
          foregroundColor: WidgetStatePropertyAll(
            filled ? const Color(0xFF0C0C0C) : Colors.white,
          ),
          overlayColor: WidgetStatePropertyAll(
            filled ? const Color(0x14000000) : const Color(0x1FFFFFFF),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              side: filled
                  ? BorderSide.none
                  : const BorderSide(color: Colors.white),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.38),
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

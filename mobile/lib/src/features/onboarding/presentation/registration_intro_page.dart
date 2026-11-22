import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistrationIntroPage extends StatelessWidget {
  const RegistrationIntroPage({super.key, this.onContinue});

  static const _designSize = Size(375, 812);
  static const _primary = Color(0xFF1EB74D);
  static const _black = Color(0xFF0C0C0C);

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: ColoredBox(
          color: Colors.white,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: _designSize,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 222,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 132,
                      top: 60,
                      width: 50,
                      height: 50,
                      child: Image.asset(
                        'assets/images/logo_marker.png',
                        key: const ValueKey('registration-header-logo'),
                        fit: BoxFit.cover,
                        semanticLabel: 'Логотип приложения Путь',
                      ),
                    ),
                    const Positioned(
                      left: 192,
                      top: 70,
                      child: Text(
                        'Путь',
                        style: TextStyle(
                          color: Color(0xFFF3F3F3),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 145,
                      width: 375,
                      height: 273,
                      child: Image.asset(
                        'assets/images/onboarding_car.png',
                        key: const ValueKey('registration-car-image'),
                        fit: BoxFit.cover,
                        semanticLabel: 'Автомобиль для совместной поездки',
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 457,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _black,
                          border: Border.all(
                            color: const Color(0xFFF6F6F7),
                            width: 3,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 16,
                              top: 32,
                              width: 343,
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    height: 1.21,
                                  ),
                                  children: [
                                    TextSpan(text: 'Добро пожаловать\nв '),
                                    TextSpan(
                                      text: 'Путь',
                                      style: TextStyle(color: _primary),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Positioned(
                              left: 16,
                              top: 108,
                              width: 343,
                              child: Text(
                                'Зарегистрируйтесь,\n'
                                'чтобы начать\n'
                                'пользоваться\n'
                                'приложением.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 16,
                              top: 236,
                              child: _RegistrationPageIndicator(),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 37,
                              height: 42,
                              child: _RegistrationContinueButton(
                                onPressed:
                                    onContinue ??
                                    () => _showPendingFlow(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showPendingFlow(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Регистрация появится далее')),
      );
  }
}

class _RegistrationPageIndicator extends StatelessWidget {
  const _RegistrationPageIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0x33E4E5E6),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: RegistrationIntroPage._primary,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _RegistrationContinueButton extends StatelessWidget {
  const _RegistrationContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('registration-continue'),
      onPressed: onPressed,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        backgroundColor: const WidgetStatePropertyAll(
          RegistrationIntroPage._primary,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: const WidgetStatePropertyAll(Color(0x1FFFFFFF)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.38),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Продолжить'),
          Icon(Icons.chevron_right_rounded, size: 14),
        ],
      ),
    );
  }
}

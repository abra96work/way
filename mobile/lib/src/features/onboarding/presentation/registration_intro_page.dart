import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistrationIntroPage extends StatelessWidget {
  const RegistrationIntroPage({super.key, this.onContinue});

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
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = (constraints.maxHeight * 0.51)
                  .clamp(330.0, 410.0)
                  .toDouble();
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: heroHeight,
                    child: const _RegistrationHero(),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
                      decoration: const BoxDecoration(
                        color: _black,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text.rich(
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
                          const SizedBox(height: 10),
                          const Text(
                            'Зарегистрируйтесь,\n'
                            'чтобы начать\n'
                            'пользоваться\n'
                            'приложением.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const Spacer(),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: _RegistrationPageIndicator(),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: _RegistrationContinueButton(
                              onPressed:
                                  onContinue ?? () => _showPendingFlow(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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

class _RegistrationHero extends StatelessWidget {
  const _RegistrationHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.58,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: RegistrationIntroPage._primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 26,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_marker.png',
                key: const ValueKey('registration-header-logo'),
                width: 42,
                height: 42,
                fit: BoxFit.contain,
                semanticLabel: 'Логотип приложения Путь',
              ),
              const SizedBox(width: 10),
              const Text(
                'Путь',
                style: TextStyle(
                  color: Color(0xFFF3F3F3),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 105,
          bottom: 0,
          child: Image.asset(
            'assets/images/onboarding_car.png',
            key: const ValueKey('registration-car-image'),
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            semanticLabel: 'Автомобиль для совместной поездки',
          ),
        ),
      ],
    );
  }
}

class _RegistrationPageIndicator extends StatelessWidget {
  const _RegistrationPageIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

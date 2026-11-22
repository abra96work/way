import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.onContinue});

  static const _designSize = Size(375, 812);
  static const _primary = Color(0xFF1EB74D);
  static const _textPrimary = Color(0xFF0C0C0C);

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
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
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      left: 16,
                      top: 79,
                      width: 343,
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
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
                    Positioned(
                      left: -2,
                      top: 164,
                      width: 378,
                      height: 290,
                      child: Image.asset(
                        'assets/images/onboarding_location.png',
                        key: const ValueKey('welcome-location-image'),
                        fit: BoxFit.cover,
                        semanticLabel: 'Метка маршрута на карте',
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 471,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 16,
                              top: 32,
                              width: 343,
                              child: Text(
                                'Находите нужное направление, создавайте поездки\n'
                                'или бронируйте места,\n'
                                'экономьте время и деньги',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 16,
                              top: 191,
                              child: _PageIndicator(),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 59,
                              height: 42,
                              child: _ContinueButton(
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
        const SnackBar(content: Text('Следующий экран появится далее')),
      );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: WelcomePage._primary,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 12,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0x33E4E5E6),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('welcome-continue'),
      onPressed: onPressed,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        backgroundColor: const WidgetStatePropertyAll(WelcomePage._primary),
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

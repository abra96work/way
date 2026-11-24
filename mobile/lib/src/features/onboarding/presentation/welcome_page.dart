import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.onContinue});

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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  children: [
                    const Text.rich(
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
                    SizedBox(height: compact ? 8 : 16),
                    Expanded(
                      flex: 5,
                      child: Image.asset(
                        'assets/images/onboarding_location.png',
                        key: const ValueKey('welcome-location-image'),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        semanticLabel: 'Метка маршрута на карте',
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    const Text(
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
                    const Spacer(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _PageIndicator(),
                    ),
                    SizedBox(height: compact ? 12 : 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: _ContinueButton(
                        onPressed:
                            onContinue ?? () => _showPendingFlow(context),
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
      mainAxisSize: MainAxisSize.min,
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
          Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

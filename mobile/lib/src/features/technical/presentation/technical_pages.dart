import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _background = Color(0xFFF1F2F3);
const _primary = Color(0xFF1EB74D);
const _text = Color(0xFF0C0C0C);
const _secondary = Color(0x7F0C0C0C);

class TechnicalLoadingPage extends StatelessWidget {
  const TechnicalLoadingPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: _background,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: _background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          key: ValueKey('technical-loading-page'),
          backgroundColor: _background,
          body: Center(
            child: SizedBox.square(
              dimension: 38,
              child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
            ),
          ),
        ),
      );
}

class TechnicalOfflinePage extends StatelessWidget {
  const TechnicalOfflinePage({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TechnicalMessagePage(
    key: const ValueKey('technical-offline-page'),
    title: 'Нет интернет-соединения',
    message: 'Проверьте, включён ли Wi‑Fi или мобильный интернет, и попробуйте снова.',
    icon: Icons.wifi_off_rounded,
    onRetry: onRetry,
  );
}

class TechnicalErrorPage extends StatelessWidget {
  const TechnicalErrorPage({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TechnicalMessagePage(
    key: const ValueKey('technical-error-page'),
    title: 'Не удалось выполнить действие',
    message:
        'Что‑то пошло не так. Проверьте интернет и повторите попытку. '
        'Если ошибка останется — зайдите позже.',
    icon: Icons.cloud_off_outlined,
    onRetry: onRetry,
  );
}

class TechnicalMessagePage extends StatelessWidget {
  const TechnicalMessagePage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: _background,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            children: [
              const Spacer(flex: 5),
              _TechnicalIllustration(icon: icon),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.29,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 15,
                  height: 1.33,
                ),
              ),
              const Spacer(flex: 6),
              FilledButton(
                key: const ValueKey('technical-retry'),
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Обновить'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TechnicalIllustration extends StatelessWidget {
  const _TechnicalIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86,
    height: 66,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: const Color(0xFFB6B8BA), size: 62),
        Positioned(
          right: 5,
          top: 8,
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: _background,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF9A9C9E), width: 2),
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Color(0xFF9A9C9E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 5,
          top: 1,
          child: Icon(Icons.auto_awesome, size: 12, color: Color(0xFFC6C8CA)),
        ),
      ],
    ),
  );
}

class TechnicalAccountBlockedPage extends StatelessWidget {
  const TechnicalAccountBlockedPage({
    super.key,
    this.reason,
    this.blockedUntil,
  });

  final String? reason;
  final DateTime? blockedUntil;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: _primary,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: _text,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      key: const ValueKey('technical-account-blocked-page'),
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            left: -34,
            right: -16,
            top: 145,
            bottom: 128,
            child: Image.asset(
              'assets/images/onboarding_car.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 177,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_marker.png',
                      width: 45,
                      height: 45,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Путь',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 34),
              decoration: const BoxDecoration(
                color: _text,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ваш аккаунт заблокирован',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description(),
                    style: const TextStyle(
                      color: Color(0xFFF3F3F3),
                      fontSize: 15,
                      height: 1.33,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _description() {
    final message = reason?.trim();
    final until = blockedUntil?.toLocal();
    final date = until == null
        ? null
        : '${until.day.toString().padLeft(2, '0')}.'
              '${until.month.toString().padLeft(2, '0')}.'
              '${until.year} ${until.hour.toString().padLeft(2, '0')}:'
              '${until.minute.toString().padLeft(2, '0')}';
    final base = message == null || message.isEmpty
        ? 'Мы ограничили доступ из-за нарушений условий использования'
        : message;
    return date == null ? base : '$base\nДоступ будет восстановлен $date';
  }
}

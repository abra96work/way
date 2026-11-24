import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PassengerAccountBlockedPage extends StatelessWidget {
  const PassengerAccountBlockedPage({
    super.key,
    this.reason,
    this.blockedUntil,
    this.onAcknowledged,
  });

  final String? reason;
  final DateTime? blockedUntil;
  final VoidCallback? onAcknowledged;

  static const _primary = Color(0xFF1EB74D);
  static const _background = Color(0xFFF1F2F3);
  static const _secondary = Color(0xFF8B8D92);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: _background,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      key: const ValueKey('account-blocked-page'),
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            children: [
              const Spacer(flex: 4),
              Image.asset(
                'assets/images/passenger/account_blocked.png',
                key: const ValueKey('account-blocked-illustration'),
                width: 104,
                height: 82,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              const Text(
                'Аккаунт временно\nзаблокирован',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                _description(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBED),
                  border: Border.all(color: const Color(0xFFE3B600)),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error, color: Color(0xFFE3B600), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Информация о блокировке передана администратору приложения',
                        style: TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 5),
              FilledButton(
                key: const ValueKey('account-blocked-acknowledge'),
                onPressed: onAcknowledged,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Понятно'),
              ),
            ],
          ),
        ),
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
    if (message != null && message.isNotEmpty && date != null) {
      return '$message\nБлокировка действует до $date';
    }
    if (message != null && message.isNotEmpty) return message;
    if (date != null) return 'Бронирование недоступно до $date';
    return 'Бронирование новых поездок временно недоступно';
  }
}

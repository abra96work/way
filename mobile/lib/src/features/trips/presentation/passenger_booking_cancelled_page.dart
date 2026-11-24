import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/passenger_booking.dart';

class PassengerBookingCancelledPage extends StatelessWidget {
  const PassengerBookingCancelledPage({
    super.key,
    required this.booking,
    this.onHome,
  });

  final PassengerBooking booking;
  final VoidCallback? onHome;

  static const _primary = Color(0xFF1EB74D);
  static const _background = Color(0xFFF1F2F3);
  static const _secondary = Color(0x7F0C0C0C);

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
      key: const ValueKey('passenger-booking-cancelled-page'),
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
            children: [
              const Spacer(flex: 4),
              Image.asset(
                'assets/images/passenger/success_check.png',
                key: const ValueKey('passenger-cancelled-success-check'),
                width: 102,
                height: 90,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'Бронь отменена',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                booking.isRefunded && booking.commission > 0
                    ? 'Заявка на возврат ${_rubles(booking.commission)} '
                          'отправлена администратору. Деньги вернутся на ту же '
                          'карту в течение 3 дней.'
                    : 'Бронирование успешно отменено.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const Spacer(flex: 5),
              FilledButton(
                key: const ValueKey('passenger-cancelled-home'),
                onPressed: onHome,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _rubles(int value) {
  final digits = value.toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end > 3 ? end - 3 : 0;
    chunks.add(digits.substring(start, end));
  }
  return '${chunks.reversed.join('\u00A0')}\u00A0₽';
}

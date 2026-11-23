import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PassengerBookingSuccessPage extends StatelessWidget {
  const PassengerBookingSuccessPage({
    super.key,
    this.onMyTrips,
    this.onMessageDriver,
  });

  final VoidCallback? onMyTrips;
  final VoidCallback? onMessageDriver;

  static const _primary = Color(0xFF1EB74D);
  static const _background = Color(0xFFF1F2F3);
  static const _secondary = Color(0xFF85878D);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: _background,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      key: const ValueKey('booking-success-page'),
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            children: [
              const Spacer(flex: 4),
              const _SuccessMark(),
              const SizedBox(height: 18),
              const Text(
                'Место забронировано',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Вы успешно забронировали место в поездке.\nДетали маршрута и данные водителя доступны\nв разделе «Мои поездки».',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary, fontSize: 14, height: 1.35),
              ),
              const Spacer(flex: 5),
              FilledButton(
                key: const ValueKey('booking-success-my-trips'),
                onPressed: onMyTrips,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Мои поездки'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('booking-success-message-driver'),
                onPressed: onMessageDriver,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Написать водителю'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 78,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: Color(0xFFDDF6E4),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: PassengerBookingSuccessPage._primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 25),
        ),
        const Positioned(
          left: 1,
          top: 14,
          child: Icon(Icons.auto_awesome, color: Color(0xFF69D683), size: 12),
        ),
        const Positioned(
          right: 0,
          top: 8,
          child: Icon(Icons.auto_awesome, color: Color(0xFF69D683), size: 10),
        ),
      ],
    ),
  );
}

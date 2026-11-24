import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../domain/passenger_api_exception.dart';
import '../domain/passenger_booking.dart';

typedef LoadPassengerBooking = Future<PassengerBooking> Function();

class PassengerBookingDetailPage extends StatefulWidget {
  const PassengerBookingDetailPage({
    super.key,
    required this.loadBooking,
    required this.onBack,
    required this.onCancel,
    required this.onPay,
    required this.onMessageDriver,
  });

  final LoadPassengerBooking loadBooking;
  final VoidCallback onBack;
  final Future<void> Function(PassengerBooking booking) onCancel;
  final Future<void> Function(PassengerBooking booking) onPay;
  final VoidCallback onMessageDriver;

  @override
  State<PassengerBookingDetailPage> createState() =>
      _PassengerBookingDetailPageState();
}

class _PassengerBookingDetailPageState
    extends State<PassengerBookingDetailPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _secondary = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);

  PassengerBooking? _booking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 375,
            height: 812,
            child: Stack(
              children: [
                Positioned.fill(child: _content()),
                if (_booking != null) _actions(_booking!),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _content() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final booking = _booking;
    if (booking == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    return CustomScrollView(
      key: const ValueKey('passenger-booking-details'),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 104),
          sliver: SliverList.list(
            children: [
              const Text(
                'Маршрут',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _routeCard(booking),
              const SizedBox(height: 12),
              _tripInfo(booking),
              const SizedBox(height: 18),
              const Text(
                'Водитель',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _driverCard(booking),
              if (booking.carPhotoUrl != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _mediaUrl(booking.carPhotoUrl!),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (booking.carName.isNotEmpty || booking.carPlate != null)
                _carCaption(booking),
              const SizedBox(height: 12),
              _priceCard(booking),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() => SizedBox(
    height: 112,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 0),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey('passenger-booking-back'),
              customBorder: const CircleBorder(),
              onTap: widget.onBack,
              child: const SizedBox.square(
                dimension: 40,
                child: Icon(Icons.chevron_left),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Поездка',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    ),
  );

  Widget _routeCard(PassengerBooking booking) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _address(booking.boardAddress, true),
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 1, height: 26, color: Colors.grey),
          ),
        ),
        _address(booking.alightAddress, false),
      ],
    ),
  );

  Widget _address(String text, bool filled) => Row(
    children: [
      Icon(filled ? Icons.square : Icons.square_outlined, size: 11),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );

  Widget _tripInfo(PassengerBooking booking) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _infoBox('Дата и время', _date(booking.departureAt)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _infoBox(
                booking.kind == 'parcel' ? 'Посылка' : 'Мест для пассажиров',
                booking.kind == 'parcel'
                    ? booking.parcelSize ?? '—'
                    : '${booking.seats}',
              ),
            ),
          ],
        ),
        if (booking.extras.isNotEmpty || booking.kind == 'parcel') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (booking.kind == 'parcel')
                Text('◈ С посылкой, ${booking.parcelSize ?? ''}')
              else
                for (final extra in booking.extras) Text(_extraLabel(extra)),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _infoBox(String label, String value) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border.all(color: _divider),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(color: _secondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _driverCard(PassengerBooking booking) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _divider,
          backgroundImage: booking.driverAvatarUrl == null
              ? null
              : NetworkImage(_mediaUrl(booking.driverAvatarUrl!)),
          child: booking.driverAvatarUrl == null
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.driverName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '★ ${booking.driverRating.toStringAsFixed(1)}  •  '
                '${booking.driverCompletedTrips} поездок',
                style: const TextStyle(color: _secondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ],
    ),
  );

  Widget _carCaption(PassengerBooking booking) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
    child: Row(
      children: [
        const Icon(Icons.directions_car_outlined, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(booking.carName, style: const TextStyle(fontSize: 12)),
        ),
        if (booking.carPlate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              booking.carPlate!,
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    ),
  );

  Widget _priceCard(PassengerBooking booking) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _priceRow(
          booking.kind == 'parcel'
              ? 'Стоимость перевозки посылки'
              : 'Стоимость поездки',
          booking.price,
        ),
        const Divider(height: 1),
        _priceRow('Комиссия', booking.commission),
        const Divider(height: 1),
        _priceRow('Оплата водителю', booking.payToDriver),
      ],
    ),
  );

  Widget _priceRow(String label, int value) => SizedBox(
    height: 44,
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          _rubles(value),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _actions(PassengerBooking booking) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    height: 94,
    child: ColoredBox(
      color: _background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
        child: booking.canPay
            ? FilledButton(
                key: const ValueKey('passenger-booking-pay'),
                onPressed: () => widget.onPay(booking),
                style: FilledButton.styleFrom(backgroundColor: _primary),
                child: const Text('Оплатить'),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('passenger-booking-cancel'),
                      onPressed: booking.canCancel
                          ? () => widget.onCancel(booking)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4B55),
                        side: const BorderSide(color: Color(0xFFFF4B55)),
                      ),
                      child: const Text('Отменить бронь'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('passenger-booking-message'),
                      onPressed: widget.onMessageDriver,
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                      child: const Text('Написать водителю'),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Future<void> _load() async {
    setState(() {
      _error = null;
      _booking = null;
    });
    try {
      final booking = await widget.loadBooking();
      if (mounted) setState(() => _booking = booking);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PassengerApiException
              ? error.message
              : 'Не удалось загрузить бронирование',
        );
      }
    }
  }
}

String _mediaUrl(String value) {
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${AppConfig.apiBaseUrl}$value';
}

String _date(DateTime? value) {
  if (value == null) return '—';
  const months = [
    'янв.',
    'февр.',
    'мар.',
    'апр.',
    'мая',
    'июня',
    'июля',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]}, '
      '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
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

String _extraLabel(String value) => switch (value) {
  'pets' => '♣ С животными',
  'luggage' => '▣ С багажом',
  'child_seat' => '♟ Дет. кресло',
  _ => value,
};

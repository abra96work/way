import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/passenger_api_exception.dart';
import '../domain/passenger_booking.dart';
import 'widgets/passenger_nav_bar.dart';

typedef LoadPassengerBookings = Future<List<PassengerBooking>> Function();

enum PassengerBookingsTab { all, created, active, completed, cancelled }

class PassengerMyBookingsPage extends StatefulWidget {
  const PassengerMyBookingsPage({
    super.key,
    required this.loadBookings,
    required this.onBookingPressed,
    this.onTrips,
    this.onChats,
    this.onProfile,
  });

  final LoadPassengerBookings loadBookings;
  final Future<void> Function(PassengerBooking booking) onBookingPressed;
  final VoidCallback? onTrips;
  final VoidCallback? onChats;
  final VoidCallback? onProfile;

  @override
  State<PassengerMyBookingsPage> createState() =>
      _PassengerMyBookingsPageState();
}

class _PassengerMyBookingsPageState extends State<PassengerMyBookingsPage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondary = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);

  PassengerBookingsTab _tab = PassengerBookingsTab.all;
  List<PassengerBooking> _bookings = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<PassengerBooking> get _visible => switch (_tab) {
    PassengerBookingsTab.all => _bookings,
    PassengerBookingsTab.created =>
      _bookings
          .where((booking) => booking.status == 'pending')
          .toList(growable: false),
    PassengerBookingsTab.active =>
      _bookings
          .where(
            (booking) =>
                booking.status == 'awaiting_payment' ||
                booking.status == 'paid',
          )
          .toList(growable: false),
    PassengerBookingsTab.completed =>
      _bookings
          .where((booking) => booking.status == 'completed')
          .toList(growable: false),
    PassengerBookingsTab.cancelled =>
      _bookings
          .where(
            (booking) =>
                booking.status == 'cancelled' || booking.status == 'rejected',
          )
          .toList(growable: false),
  };

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
            child: Column(
              children: [
                const SizedBox(height: 54),
                const SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(
                      'Мои заказы',
                      key: ValueKey('passenger-my-bookings-title'),
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _tabs(),
                Expanded(child: _content()),
                PassengerNavBar(
                  current: PassengerNavTab.orders,
                  onSelect: (tab) => switch (tab) {
                    PassengerNavTab.trips => widget.onTrips?.call(),
                    PassengerNavTab.orders => null,
                    PassengerNavTab.chats => widget.onChats?.call(),
                    PassengerNavTab.profile => widget.onProfile?.call(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _tabs() => SizedBox(
    height: 52,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      children: [
        _tabButton(PassengerBookingsTab.all, 'Все'),
        _tabButton(PassengerBookingsTab.created, 'Созданные'),
        _tabButton(PassengerBookingsTab.active, 'Активные'),
        _tabButton(PassengerBookingsTab.completed, 'Завершённые'),
        _tabButton(PassengerBookingsTab.cancelled, 'Отменённые'),
      ],
    ),
  );

  Widget _tabButton(PassengerBookingsTab tab, String label) {
    final selected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        key: ValueKey('passenger-bookings-tab-${tab.name}'),
        onPressed: () => setState(() => _tab = tab),
        style: OutlinedButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          foregroundColor: _text,
          side: BorderSide(color: selected ? _primary : _divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
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
    final bookings = _visible;
    if (bookings.isEmpty) return const _EmptyBookings();
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView.separated(
        key: const ValueKey('passenger-my-bookings-list'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _BookingCard(
            booking: booking,
            onTap: () async {
              await widget.onBookingPressed(booking);
              if (mounted) await _load();
            },
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await widget.loadBookings();
      if (mounted) setState(() => _bookings = bookings);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PassengerApiException
              ? error.message
              : 'Не удалось загрузить заказы',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      key: const ValueKey('passenger-my-bookings-empty'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/passenger/empty_trips.png',
          width: 82,
          height: 72,
        ),
        const SizedBox(height: 12),
        const Text(
          'У вас пока нет заказов',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Выберите подходящую поездку на главном экране',
          style: TextStyle(color: _PassengerMyBookingsPageState._secondary),
        ),
      ],
    ),
  );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

  final PassengerBooking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('passenger-booking-${booking.id}'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.number == null
                        ? 'Заказ'
                        : 'Заказ №${booking.number}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _StatusBadge(booking: booking),
              ],
            ),
            const SizedBox(height: 10),
            _AddressRow(address: booking.boardAddress, filled: true),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Container(width: 1, height: 12, color: Colors.grey),
            ),
            _AddressRow(address: booking.alightAddress, filled: false),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (booking.kind == 'parcel')
                  Text('◈ Посылка ${booking.parcelSize ?? ''}'.trim())
                else
                  Text('♟ ${booking.seats} ${_seatWord(booking.seats)}'),
                for (final extra in booking.extras) Text(_extraLabel(extra)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _PassengerMyBookingsPageState._divider,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 15),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_date(booking.departureAt))),
                  Text(
                    _rubles(booking.price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.booking});

  final PassengerBooking booking;

  @override
  Widget build(BuildContext context) {
    final label = switch (booking.status) {
      'pending' => 'Заявка отправлена',
      'awaiting_payment' => 'Ожидает оплаты',
      'paid' => 'Оплачено',
      'completed' => 'Завершено',
      'cancelled' => 'Отменено',
      'rejected' => 'Отклонено',
      _ => booking.status,
    };
    final negative =
        booking.status == 'cancelled' || booking.status == 'rejected';
    final color = negative
        ? const Color(0xFFFF4B55)
        : _PassengerMyBookingsPageState._primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.filled});
  final String address;
  final bool filled;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        filled ? Icons.square : Icons.square_outlined,
        size: 11,
        color: _PassengerMyBookingsPageState._text,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

String _date(DateTime? value) {
  if (value == null) return 'Дата не указана';
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
  final parts = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    parts.add(digits.substring((end - 3).clamp(0, end), end));
  }
  return '${parts.reversed.join('\u00A0')}\u00A0₽';
}

String _seatWord(int value) {
  if (value % 10 == 1 && value % 100 != 11) return 'место';
  if (value % 10 >= 2 &&
      value % 10 <= 4 &&
      (value % 100 < 12 || value % 100 > 14)) {
    return 'места';
  }
  return 'мест';
}

String _extraLabel(String value) => switch (value) {
  'pets' => '♣ С животными',
  'luggage' => '▣ С багажом',
  'child_seat' => '♟ Дет. кресло',
  _ => value,
};

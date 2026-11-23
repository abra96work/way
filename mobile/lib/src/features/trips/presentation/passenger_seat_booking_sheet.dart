import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/passenger_booking.dart';
import '../domain/passenger_trip.dart';

const _primary = Color(0xFF1EB74D);
const _background = Color(0xFFF1F2F3);
const _text = Color(0xFF151619);
const _secondary = Color(0xFF929499);
const _divider = Color(0xFFE1E3E5);

Future<PassengerSeatBookingDraft?> showPassengerSeatBookingSheet(
  BuildContext context, {
  required PassengerTripDetails details,
}) => showModalBottomSheet<PassengerSeatBookingDraft>(
  context: context,
  isScrollControlled: true,
  useSafeArea: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.36),
  builder: (_) => _SeatBookingSheet(details: details),
);

class _SeatBookingSheet extends StatefulWidget {
  const _SeatBookingSheet({required this.details});

  final PassengerTripDetails details;

  @override
  State<_SeatBookingSheet> createState() => _SeatBookingSheetState();
}

class _SeatBookingSheetState extends State<_SeatBookingSheet> {
  late int _fromPosition;
  late int _toPosition;
  late final Set<String> _selectedExtras;
  int _seats = 1;

  List<PassengerExtraOption> get _extras {
    if (widget.details.extraOptions.isNotEmpty) {
      return widget.details.extraOptions;
    }
    return widget.details.extras
        .map((kind) => PassengerExtraOption(kind: kind, price: 0))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _fromPosition = widget.details.stops.first.position;
    _toPosition = widget.details.stops.last.position;
    _selectedExtras = _extras.map((option) => option.kind).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.details.stops;
    final departureStops = stops.take(math.max(0, stops.length - 1)).toList();
    final arrivalStops = stops
        .where((stop) => stop.position > _fromPosition)
        .toList(growable: false);
    final maxSeats = math.max(1, widget.details.seatsAvailable);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        key: const ValueKey('seat-booking-sheet'),
        color: _background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: math.min(780, MediaQuery.sizeOf(context).height - 24),
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Точка отправления'),
                      const SizedBox(height: 8),
                      _StopCard(
                        stops: departureStops,
                        selectedPosition: _fromPosition,
                        prefix: 'from',
                        onSelected: _selectDeparture,
                      ),
                      const SizedBox(height: 14),
                      const _Label('Конечная точка'),
                      const SizedBox(height: 8),
                      _StopCard(
                        stops: arrivalStops,
                        selectedPosition: _toPosition,
                        prefix: 'to',
                        onSelected: (position) =>
                            setState(() => _toPosition = position),
                      ),
                      const SizedBox(height: 14),
                      const _Label('Доп. услуги'),
                      const SizedBox(height: 8),
                      _ExtrasCard(
                        options: _extras,
                        selected: _selectedExtras,
                        onChanged: (kind, value) => setState(() {
                          value
                              ? _selectedExtras.add(kind)
                              : _selectedExtras.remove(kind);
                        }),
                      ),
                      const SizedBox(height: 14),
                      _PassengerCount(
                        value: _seats,
                        max: maxSeats,
                        onChanged: (value) => setState(() => _seats = value),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                child: FilledButton(
                  key: const ValueKey('seat-booking-submit'),
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Отправить заявку'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDeparture(int position) {
    final validArrivals = widget.details.stops
        .where((stop) => stop.position > position)
        .toList();
    setState(() {
      _fromPosition = position;
      if (_toPosition <= position && validArrivals.isNotEmpty) {
        _toPosition = validArrivals.last.position;
      }
    });
  }

  void _submit() => Navigator.of(context).pop(
    PassengerSeatBookingDraft(
      tripId: widget.details.id,
      fromPosition: _fromPosition,
      toPosition: _toPosition,
      seats: _seats,
      extras: _selectedExtras.toList(growable: false)..sort(),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 74,
    child: Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 43,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD0D2D4),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 9),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Откликнуться на заказ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stops,
    required this.selectedPosition,
    required this.prefix,
    required this.onSelected,
  });

  final List<PassengerStop> stops;
  final int selectedPosition;
  final String prefix;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    color: Colors.white,
    child: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _RoadPainter())),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Column(
            children: [
              for (final stop in stops)
                InkWell(
                  key: ValueKey('seat-$prefix-${stop.position}'),
                  onTap: () => onSelected(stop.position),
                  child: SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        _RadioMark(selected: stop.position == selectedPosition),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            stop.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: _primary, width: 2),
    ),
    alignment: Alignment.center,
    child: selected
        ? const DecoratedBox(
            decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: SizedBox.square(dimension: 12),
          )
        : null,
  );
}

class _ExtrasCard extends StatelessWidget {
  const _ExtrasCard({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<PassengerExtraOption> options;
  final Set<String> selected;
  final void Function(String kind, bool value) onChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          _ExtraRow(
            option: options[index],
            value: selected.contains(options[index].kind),
            onChanged: (value) => onChanged(options[index].kind, value),
          ),
          if (index != options.length - 1)
            const Divider(height: 1, color: _divider),
        ],
      ],
    ),
  );
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.option,
    required this.value,
    required this.onChanged,
  });

  final PassengerExtraOption option;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final data = _extraData(option.kind);
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          Icon(data.icon, size: 19, color: _secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.subtitle,
                  style: const TextStyle(color: _secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            key: ValueKey('seat-extra-${option.kind}'),
            value: value,
            onChanged: onChanged,
            activeTrackColor: _primary,
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD7D9DA),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _PassengerCount extends StatelessWidget {
  const _PassengerCount({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 70,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Пассажиров',
            style: TextStyle(color: Color(0xFF5E6065), fontSize: 15),
          ),
        ),
        _CounterButton(
          key: const ValueKey('seat-passengers-minus'),
          icon: Icons.remove,
          enabled: value > 1,
          onPressed: () => onChanged(value - 1),
        ),
        SizedBox(width: 52, child: Text('$value', textAlign: TextAlign.center)),
        _CounterButton(
          key: const ValueKey('seat-passengers-plus'),
          icon: Icons.add,
          enabled: value < max,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    ),
  );
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: _divider),
    ),
    child: InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 42,
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF8A8D91)
                  : const Color(0xFFE4E5E6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .46, 6)
      ..cubicTo(
        size.width * .95,
        size.height * .05,
        size.width * .78,
        size.height * .7,
        size.width * .5,
        size.height,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF3F4F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

({String title, String subtitle, IconData icon}) _extraData(String kind) =>
    switch (kind) {
      'child_seat' => (
        title: 'Детское кресло',
        subtitle: 'Детское кресло',
        icon: Icons.child_friendly,
      ),
      'luggage' => (
        title: 'Багаж',
        subtitle: 'Большой чемодан',
        icon: Icons.luggage,
      ),
      'pets' => (
        title: 'Животные',
        subtitle: 'В переноске или на коленях',
        icon: Icons.pets,
      ),
      _ => (title: kind, subtitle: '', icon: Icons.add_circle_outline),
    };

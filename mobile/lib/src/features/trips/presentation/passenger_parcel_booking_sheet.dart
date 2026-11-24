import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters/money.dart';
import '../domain/passenger_trip.dart';

const _primary = Color(0xFF1EB74D);
const _background = Color(0xFFF1F2F3);
const _surface = Colors.white;
const _text = Color(0xFF101114);
const _secondary = Color(0xFF8B8D92);
const _divider = Color(0xFFE3E5E7);

class PassengerParcelBookingDraft {
  const PassengerParcelBookingDraft({
    required this.tripId,
    required this.fromPosition,
    required this.toPosition,
    required this.parcelSize,
    required this.comment,
    required this.withoutPassenger,
  });

  final String tripId;
  final int fromPosition;
  final int toPosition;
  final String parcelSize;
  final String comment;
  final bool withoutPassenger;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trip_id': tripId,
    'kind': 'parcel',
    'from_position': fromPosition,
    'to_position': toPosition,
    'seats': 1,
    'extras': const <String>[],
    'parcel_size': parcelSize,
  };
}

Future<PassengerParcelBookingDraft?> showPassengerParcelBookingSheet(
  BuildContext context, {
  required PassengerTripDetails details,
}) => showModalBottomSheet<PassengerParcelBookingDraft>(
  context: context,
  isScrollControlled: true,
  useSafeArea: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.36),
  builder: (_) => _ParcelBookingSheet(details: details),
);

class _ParcelBookingSheet extends StatefulWidget {
  const _ParcelBookingSheet({required this.details});

  final PassengerTripDetails details;

  @override
  State<_ParcelBookingSheet> createState() => _ParcelBookingSheetState();
}

class _ParcelBookingSheetState extends State<_ParcelBookingSheet> {
  final _commentController = TextEditingController();
  PassengerParcelOption? _selectedOption;
  bool _withoutPassenger = true;

  List<PassengerParcelOption> get _options =>
      _resolvedParcelOptions(widget.details);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxPrice = _options.fold<int>(
      0,
      (value, option) => math.max(value, option.price),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          key: const ValueKey('parcel-booking-sheet'),
          color: _background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: math.min(584, MediaQuery.sizeOf(context).height - keyboard),
            child: Column(
              children: [
                const _SheetHeader(title: 'Откликнуться на заказ'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Маршрут'),
                        const SizedBox(height: 8),
                        _ParcelRouteCard(stops: widget.details.stops),
                        const SizedBox(height: 14),
                        const _SectionLabel('Доп. услуги'),
                        const SizedBox(height: 8),
                        _ParcelServiceCard(
                          selected: _selectedOption,
                          maxPrice: maxPrice,
                          onTap: _chooseParcelSize,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
                          child: _CommentField(controller: _commentController),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: _WithoutPassengerRow(
                            value: _withoutPassenger,
                            onChanged: (value) =>
                                setState(() => _withoutPassenger = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: FilledButton(
                    key: const ValueKey('parcel-continue-to-payment'),
                    onPressed: _selectedOption == null ? null : _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: _primary,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: _secondary,
                      side: BorderSide(
                        color: _selectedOption == null ? _divider : _primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Перейти к оплате'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseParcelSize() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<PassengerParcelOption>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) =>
          _ParcelSizeSheet(options: _options, initialValue: _selectedOption),
    );
    if (mounted && selected != null) {
      setState(() => _selectedOption = selected);
    }
  }

  void _continue() {
    final option = _selectedOption;
    if (option == null) return;
    Navigator.of(context).pop(
      PassengerParcelBookingDraft(
        tripId: widget.details.id,
        fromPosition: widget.details.stops.first.position,
        toPosition: widget.details.stops.last.position,
        parcelSize: option.size,
        comment: _commentController.text.trim(),
        withoutPassenger: _withoutPassenger,
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

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
            color: const Color(0xFFD2D4D6),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.22,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      text,
      style: const TextStyle(
        color: _text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ParcelRouteCard extends StatelessWidget {
  const _ParcelRouteCard({required this.stops});

  final List<PassengerStop> stops;

  @override
  Widget build(BuildContext context) {
    final first = stops.isEmpty ? '' : stops.first.address;
    final last = stops.length < 2 ? '' : stops.last.address;
    final intermediate = math.max(0, stops.length - 2);
    return Container(
      height: 112,
      color: _surface,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _RoadPainter())),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _RouteStops(
              first: first,
              last: last,
              intermediate: intermediate,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStops extends StatelessWidget {
  const _RouteStops({
    required this.first,
    required this.last,
    required this.intermediate,
  });

  final String first;
  final String last;
  final int intermediate;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 10,
        height: 80,
        child: CustomPaint(painter: _RouteLinePainter()),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(first, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8ED),
                border: Border.all(color: _primary),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$intermediate ${_stopWord(intermediate)} ⌄',
                style: const TextStyle(color: _primary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 9),
            Text(last, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

class _ParcelServiceCard extends StatelessWidget {
  const _ParcelServiceCard({
    required this.selected,
    required this.maxPrice,
    required this.onTap,
  });

  final PassengerParcelOption? selected;
  final int maxPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _surface,
    child: InkWell(
      key: const ValueKey('parcel-size-picker'),
      onTap: onTap,
      child: SizedBox(
        height: 82,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: _secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null
                          ? 'Посылка'
                          : 'Посылка ${selected!.size}',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected == null
                          ? 'Груз различного веса'
                          : _optionSubtitle(selected!),
                      style: const TextStyle(color: _secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                selected == null
                    ? 'до ${formatRubles(maxPrice)}'
                    : '+${formatRubles(selected!.price)}',
                style: const TextStyle(color: _primary, fontSize: 14),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.chevron_right, color: _text, size: 21),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CommentField extends StatefulWidget {
  const _CommentField({required this.controller});

  final TextEditingController controller;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Комментарий',
        style: TextStyle(color: _secondary, fontSize: 13),
      ),
      TextField(
        key: const ValueKey('parcel-comment'),
        controller: widget.controller,
        maxLength: 250,
        minLines: 1,
        maxLines: 2,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Вид посылки',
          hintStyle: const TextStyle(color: _secondary, fontSize: 13),
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _primary),
          ),
          suffix: Text(
            '${widget.controller.text.characters.length}/250',
            style: const TextStyle(color: _secondary, fontSize: 12),
          ),
        ),
      ),
    ],
  );
}

class _WithoutPassengerRow extends StatelessWidget {
  const _WithoutPassengerRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.person_off_outlined, size: 18, color: _secondary),
      ),
      const SizedBox(width: 8),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Без проезда пассажира', style: TextStyle(fontSize: 14)),
            SizedBox(height: 3),
            Text(
              'Можно отправить только посылку, без места в авто',
              style: TextStyle(color: _secondary, fontSize: 12, height: 1.35),
            ),
          ],
        ),
      ),
      Switch(
        key: const ValueKey('parcel-without-passenger'),
        value: value,
        onChanged: onChanged,
        activeTrackColor: _primary,
        activeThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFDADCDD),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ],
  );
}

class _ParcelSizeSheet extends StatefulWidget {
  const _ParcelSizeSheet({required this.options, required this.initialValue});

  final List<PassengerParcelOption> options;
  final PassengerParcelOption? initialValue;

  @override
  State<_ParcelSizeSheet> createState() => _ParcelSizeSheetState();
}

class _ParcelSizeSheetState extends State<_ParcelSizeSheet> {
  PassengerParcelOption? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Material(
      key: const ValueKey('parcel-size-sheet'),
      color: _background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: math.min(412, MediaQuery.sizeOf(context).height),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHeader(title: 'Посылка'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Укажите размер вашей посылки',
                style: TextStyle(color: _secondary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  return _ParcelOptionTile(
                    option: option,
                    selected: option.size == _selected?.size,
                    onTap: () => setState(() => _selected = option),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('parcel-size-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('parcel-size-add'),
                      onPressed: _selected == null
                          ? null
                          : () => Navigator.of(context).pop(_selected),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Добавить'),
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

class _ParcelOptionTile extends StatelessWidget {
  const _ParcelOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PassengerParcelOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFE8F8ED) : _surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? _primary : _divider),
    ),
    child: InkWell(
      key: ValueKey('parcel-option-${option.size}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Image.asset(
                _parcelAsset(option.size),
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _optionName(option.size),
                      style: const TextStyle(fontSize: 15, color: _text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _optionSubtitle(option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _secondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '+${formatRubles(option.price)}',
                style: const TextStyle(color: _primary, fontSize: 14),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected ? _primary : Colors.transparent,
                  border: Border.all(color: _primary, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ],
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
    final paint = Paint()
      ..color = const Color(0xFFF4F5F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .48, size.height * .18)
      ..cubicTo(
        size.width * .93,
        size.height * .15,
        size.width * .82,
        size.height * .72,
        size.width * .45,
        size.height * .98,
      );
    canvas.drawPath(path, paint);
    paint
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _secondary
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(5, 8), Offset(5, size.height - 8), line);
    canvas.drawRect(const Rect.fromLTWH(1, 0, 8, 8), Paint()..color = _text);
    canvas.drawCircle(Offset(5, size.height / 2), 2.5, Paint()..color = _text);
    canvas.drawRect(
      Rect.fromLTWH(1, size.height - 8, 8, 8),
      Paint()
        ..color = _surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(1, size.height - 8, 8, 8),
      Paint()
        ..color = _text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

List<PassengerParcelOption> _resolvedParcelOptions(
  PassengerTripDetails details,
) {
  if (details.parcelOptions.isNotEmpty) return details.parcelOptions;
  const defaults = <String, PassengerParcelOption>{
    'S': PassengerParcelOption(
      size: 'S',
      maxDimensionsCm: [30, 30, 20],
      maxWeightKg: 5,
      price: 150,
    ),
    'M': PassengerParcelOption(
      size: 'M',
      maxDimensionsCm: [50, 40, 30],
      maxWeightKg: 10,
      price: 250,
    ),
    'L': PassengerParcelOption(
      size: 'L',
      maxDimensionsCm: [80, 60, 40],
      maxWeightKg: 20,
      price: 350,
    ),
  };
  return details.parcelSizes
      .map((size) => defaults[size])
      .whereType<PassengerParcelOption>()
      .toList(growable: false);
}

String _optionName(String size) => switch (size) {
  'S' => 'Маленькая',
  'M' => 'Средняя',
  'L' => 'Большая',
  _ => 'Посылка $size',
};

String _optionSubtitle(PassengerParcelOption option) {
  if (option.size == 'S') return 'Конверты, ключи...';
  final dimensions = option.maxDimensionsCm.join('/');
  return 'до $dimensions см, до ${option.maxWeightKg} кг';
}

String _parcelAsset(String size) => switch (size) {
  'S' => 'assets/images/passenger/parcel_small.png',
  'M' => 'assets/images/passenger/parcel_medium.png',
  _ => 'assets/images/passenger/parcel_large.png',
};

String _stopWord(int value) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'остановок';
  if (mod10 == 1) return 'остановка';
  if (mod10 >= 2 && mod10 <= 4) return 'остановки';
  return 'остановок';
}

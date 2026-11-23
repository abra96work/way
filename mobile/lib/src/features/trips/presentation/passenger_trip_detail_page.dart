import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/config/app_config.dart';
import '../domain/passenger_booking.dart';
import '../domain/passenger_trip.dart';
import 'passenger_parcel_booking_sheet.dart';
import 'passenger_seat_booking_sheet.dart';

typedef LoadPassengerTripDetails = Future<PassengerTripDetails> Function();
typedef SubmitPassengerSeatBooking = Future<void> Function(
  PassengerSeatBookingDraft draft,
);

class PassengerTripDetailPage extends StatefulWidget {
  const PassengerTripDetailPage({
    super.key,
    this.loadDetails,
    this.initialDetails,
    this.onBack,
    this.onBookSeat,
    this.onSendParcel,
    this.booking,
    this.onCancelBooking,
    this.onMessageDriver,
  }) : assert(loadDetails != null || initialDetails != null);

  final LoadPassengerTripDetails? loadDetails;
  final PassengerTripDetails? initialDetails;
  final VoidCallback? onBack;
  final SubmitPassengerSeatBooking? onBookSeat;
  final VoidCallback? onSendParcel;
  final PassengerBooking? booking;
  final VoidCallback? onCancelBooking;
  final VoidCallback? onMessageDriver;

  @override
  State<PassengerTripDetailPage> createState() =>
      _PassengerTripDetailPageState();
}

class _PassengerTripDetailPageState extends State<PassengerTripDetailPage> {
  static const _designSize = Size(375, 812);
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondary = Color(0xFF61636B);
  static const _divider = Color(0xFFE4E5E6);

  PassengerTripDetails? _details;
  String? _error;
  bool _routeExpanded = false;
  bool _pricesExpanded = false;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails;
    _setInitialExpansion(widget.initialDetails);
    if (widget.loadDetails != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _background,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: ColoredBox(
          color: _background,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: _designSize,
                child: Stack(
                  children: [
                    _DetailHeader(onBack: widget.onBack),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 114,
                      bottom: 0,
                      child: _buildContent(),
                    ),
                    if (_details != null && widget.booking?.isPaid == true)
                      _PaidActions(
                        onCancel: widget.onCancelBooking,
                        onMessage: widget.onMessageDriver,
                      )
                    else if (_details != null)
                      _DetailActions(
                        details: _details!,
                        onBookSeat: () => _openSeatBooking(_details!),
                        onSendParcel: () => _openParcelBooking(_details!),
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

  Widget _buildContent() {
    final details = _details;
    if (details == null && _error == null) {
      return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
      );
    }
    if (details == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Не удалось загрузить поездку'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    return ListView(
      key: const ValueKey('passenger-trip-details'),
      padding: const EdgeInsets.only(top: 10, bottom: 150),
      children: [
        const _SectionTitle('Маршрут'),
        const SizedBox(height: 12),
        _RouteCard(
          details: details,
          expanded: _routeExpanded,
          onToggle: () => setState(() => _routeExpanded = !_routeExpanded),
        ),
        const SizedBox(height: 12),
        _TripInfoCard(details: details),
        const SizedBox(height: 20),
        const _SectionTitle('Водитель'),
        const SizedBox(height: 12),
        _DriverCard(details: details),
        const SizedBox(height: 20),
        if (widget.booking?.isPaid == true)
          _PaidPriceCard(booking: widget.booking!)
        else
          _PriceCard(
            details: details,
            expanded: _pricesExpanded,
            onToggle: () => setState(() => _pricesExpanded = !_pricesExpanded),
          ),
      ],
    );
  }

  Future<void> _openSeatBooking(PassengerTripDetails details) async {
    final draft = await showPassengerSeatBookingSheet(
      context,
      details: details,
    );
    if (draft == null || !mounted) return;
    try {
      await widget.onBookSeat?.call(draft);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку')),
        );
    }
  }

  Future<void> _openParcelBooking(PassengerTripDetails details) async {
    final draft = await showPassengerParcelBookingSheet(
      context,
      details: details,
    );
    if (draft != null && mounted) widget.onSendParcel?.call();
  }

  Future<void> _load() async {
    final loader = widget.loadDetails;
    if (loader == null) return;
    setState(() => _error = null);
    try {
      final details = await loader();
      if (!mounted) return;
      setState(() {
        _details = details;
        _setInitialExpansion(details);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'load_failed');
    }
  }

  void _setInitialExpansion(PassengerTripDetails? details) {
    final hasSeats = (details?.seatsAvailable ?? 0) > 0;
    _routeExpanded = hasSeats;
    _pricesExpanded = hasSeats;
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 54,
      height: 60,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Center(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('passenger-detail-back'),
                  customBorder: const CircleBorder(),
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/passenger/back.svg',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Поездка',
              key: ValueKey('passenger-detail-title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.details,
    required this.expanded,
    required this.onToggle,
  });

  final PassengerTripDetails details;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final stops = details.stops;
    final intermediates = stops.length > 2 ? stops.length - 2 : 0;
    final shownIntermediates = expanded ? intermediates : 0;
    final contentHeight = 80.0 + shownIntermediates * 28;
    return Container(
      key: const ValueKey('passenger-detail-route'),
      height: contentHeight + 32,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -16,
            width: expanded ? 293 : 284,
            height: expanded ? 169 : 164,
            child: SvgPicture.asset('assets/icons/passenger/road.svg'),
          ),
          Positioned.fill(
            child: _RouteStops(
              stops: stops,
              intermediates: intermediates,
              expanded: expanded,
              onToggle: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStops extends StatelessWidget {
  const _RouteStops({
    required this.stops,
    required this.intermediates,
    required this.expanded,
    required this.onToggle,
  });

  final List<PassengerStop> stops;
  final int intermediates;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final first = stops.isEmpty ? '' : stops.first.address;
    final last = stops.isEmpty ? '' : stops.last.address;
    final shown = expanded ? intermediates : 0;
    final endTop = 65.0 + shown * 28;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _DetailAddress(text: first, start: true),
        ),
        for (var index = 0; index <= shown; index++)
          Positioned(
            left: 0,
            top: 15.0 + index * 28,
            child: SvgPicture.asset('assets/icons/passenger/route_line.svg'),
          ),
        if (intermediates > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 28,
            child: _StopsToggle(
              count: intermediates,
              expanded: expanded,
              onTap: onToggle,
            ),
          ),
        if (expanded)
          for (var index = 0; index < intermediates; index++)
            Positioned(
              left: 0,
              right: 0,
              top: 56.0 + index * 28,
              child: _IntermediateAddress(text: stops[index + 1].address),
            ),
        Positioned(
          left: 0,
          right: 0,
          top: endTop,
          child: _DetailAddress(text: last, start: false),
        ),
      ],
    );
  }
}

class _StopsToggle extends StatelessWidget {
  const _StopsToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 10,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _PassengerTripDetailPageState._primary,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 6),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        height: 24,
        child: OutlinedButton(
          key: const ValueKey('passenger-detail-stops-toggle'),
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: _PassengerTripDetailPageState._primary,
            side: const BorderSide(
              color: _PassengerTripDetailPageState._primary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count ${_stopsWord(count)}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 2),
              Transform.rotate(
                angle: expanded ? math.pi : 0,
                child: SvgPicture.asset(
                  'assets/icons/passenger/arrow_down.svg',
                  width: 12,
                  height: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _IntermediateAddress extends StatelessWidget {
  const _IntermediateAddress({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 10,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x7F0C0C0C),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 6),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}

class _DetailAddress extends StatelessWidget {
  const _DetailAddress({required this.text, required this.start});

  final String text;
  final bool start;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: start
              ? _PassengerTripDetailPageState._text
              : Colors.transparent,
          border: start
              ? null
              : Border.all(
                  color: _PassengerTripDetailPageState._text,
                  width: 2,
                ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    ],
  );
}

class _TripInfoCard extends StatelessWidget {
  const _TripInfoCard({required this.details});

  final PassengerTripDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _InfoBox(
                label: 'Дата и время',
                value: _detailDate(details.departureAt),
              ),
              const SizedBox(width: 4),
              _InfoBox(
                label: 'Мест свободно',
                value: '${details.seatsAvailable} из ${details.seatsTotal}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (details.extras.contains('luggage'))
                const _DetailTag('bag.svg', 'С багажом'),
              if (details.extras.contains('pets'))
                const _DetailTag('paw.svg', 'С животными'),
              if (details.extras.contains('child_seat'))
                const _DetailTag('baby.svg', 'Дет. кресло'),
              if (details.parcelSizes.isNotEmpty)
                _DetailTag(
                  'parcel.svg',
                  'Посылка ${details.parcelSizes.join(', ')}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: _PassengerTripDetailPageState._divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _DetailTag extends StatelessWidget {
  const _DetailTag(this.icon, this.label);

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 14,
        child: SvgPicture.asset('assets/icons/passenger/$icon'),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.details});

  final PassengerTripDetails details;

  @override
  Widget build(BuildContext context) {
    final avatar = _detailMediaUrl(details.driverAvatarUrl);
    final carPhoto = _detailMediaUrl(details.carPhotoUrl);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 38,
                  child: avatar == null
                      ? const ColoredBox(
                          color: _PassengerTripDetailPageState._divider,
                          child: Icon(Icons.person),
                        )
                      : Image.network(avatar, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.driverName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 14,
                          child: SvgPicture.asset(
                            'assets/icons/passenger/star.svg',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          details.driverRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _PassengerTripDetailPageState._secondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '•  ${details.completedTrips} поездок',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _PassengerTripDetailPageState._secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _PassengerTripDetailPageState._divider,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/passenger/arrow_right.svg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: carPhoto == null
                  ? const ColoredBox(
                      color: _PassengerTripDetailPageState._divider,
                      child: Icon(
                        Icons.directions_car,
                        size: 64,
                        color: _PassengerTripDetailPageState._secondary,
                      ),
                    )
                  : Image.network(carPhoto, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox.square(
                dimension: 16,
                child: SvgPicture.asset('assets/icons/passenger/car.svg'),
              ),
              const SizedBox(width: 4),
              Text(details.carName, style: const TextStyle(fontSize: 13)),
              if (details.carPlate case final plate?) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _PassengerTripDetailPageState._text,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(plate, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.details,
    required this.expanded,
    required this.onToggle,
  });

  final PassengerTripDetails details;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final stops = {for (final stop in details.stops) stop.position: stop};
    final adjacent =
        details.segmentPrices
            .where((price) => price.toPosition == price.fromPosition + 1)
            .toList(growable: false)
          ..sort((a, b) => a.fromPosition.compareTo(b.fromPosition));
    return Container(
      key: const ValueKey('passenger-detail-price-card'),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Стоимость поездки',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Text(
                  '${details.price} ₽',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0, thickness: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Между остановками',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: OutlinedButton(
                    key: const ValueKey('passenger-detail-price-toggle'),
                    onPressed: adjacent.isEmpty ? null : onToggle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: _PassengerTripDetailPageState._primary,
                      side: const BorderSide(
                        color: _PassengerTripDetailPageState._primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Смотреть стоимость',
                          style: TextStyle(fontSize: 11),
                        ),
                        const SizedBox(width: 2),
                        Transform.rotate(
                          angle: expanded ? math.pi : 0,
                          child: SvgPicture.asset(
                            'assets/icons/passenger/arrow_down.svg',
                            width: 12,
                            height: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            for (var index = 0; index < adjacent.length; index++) ...[
              const Divider(height: 0, thickness: 1, indent: 16, endIndent: 16),
              _SegmentPriceRow(
                price: adjacent[index],
                from: stops[adjacent[index].fromPosition]?.address ?? '',
                to: stops[adjacent[index].toPosition]?.address ?? '',
              ),
            ],
        ],
      ),
    );
  }
}

class _SegmentPriceRow extends StatelessWidget {
  const _SegmentPriceRow({
    required this.price,
    required this.from,
    required this.to,
  });

  final PassengerSegmentPrice price;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$from -\n$to',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.38),
          ),
        ),
        const SizedBox(width: 12),
        Text('${price.price}₽', style: const TextStyle(fontSize: 15)),
      ],
    ),
  );
}

class _PaidPriceCard extends StatelessWidget {
  const _PaidPriceCard({required this.booking});

  final PassengerBooking booking;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('passenger-paid-price-card'),
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(
      children: [
        _PaymentRow(label: 'Стоимость поездки', value: booking.price),
        const Divider(height: 1),
        _PaymentRow(label: 'Комиссия', value: booking.commission),
        const Divider(height: 1),
        _PaymentRow(label: 'Оплата водителю', value: booking.payToDriver),
      ],
    ),
  );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          '$value ₽',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _PaidActions extends StatelessWidget {
  const _PaidActions({this.onCancel, this.onMessage});

  final VoidCallback? onCancel;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    height: 92,
    child: ColoredBox(
      color: _PassengerTripDetailPageState._background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('passenger-paid-cancel'),
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: const Color(0xFFFF4B55),
                  side: const BorderSide(color: Color(0xFFFF4B55)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Отменить бронь'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const ValueKey('passenger-paid-message'),
                onPressed: onMessage,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: _PassengerTripDetailPageState._primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Написать водителю'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.details,
    this.onBookSeat,
    this.onSendParcel,
  });

  final PassengerTripDetails details;
  final VoidCallback? onBookSeat;
  final VoidCallback? onSendParcel;

  @override
  Widget build(BuildContext context) {
    final seatsAvailable = details.seatsAvailable > 0;
    final parcelsAvailable = details.parcelSizes.isNotEmpty;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 134,
      child: ColoredBox(
        color: _PassengerTripDetailPageState._background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
          child: Column(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('passenger-book-seat'),
                  onPressed: seatsAvailable ? onBookSeat : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: _PassengerTripDetailPageState._primary,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor:
                        _PassengerTripDetailPageState._secondary,
                    side: BorderSide(
                      color: seatsAvailable
                          ? _PassengerTripDetailPageState._primary
                          : _PassengerTripDetailPageState._divider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    seatsAvailable ? 'Забронировать место' : 'Мест нет',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('passenger-send-parcel'),
                  onPressed: parcelsAvailable ? onSendParcel : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    foregroundColor: _PassengerTripDetailPageState._primary,
                    side: const BorderSide(
                      color: _PassengerTripDetailPageState._primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Отправить посылку'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _detailDate(DateTime value) {
  const months = <String>[
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

String _stopsWord(int value) {
  if (value == 1) return 'остановка';
  if (value >= 2 && value <= 4) return 'остановки';
  return 'остановок';
}

String? _detailMediaUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${AppConfig.apiBaseUrl}$value';
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/config/app_config.dart';
import '../domain/passenger_trip.dart';
import '../services/passenger_location_service.dart';
import 'passenger_trip_filter_sheet.dart';

typedef LoadPassengerTrips = Future<List<PassengerTrip>> Function(
  String type,
  PassengerTripFilter filter,
);

class PassengerTripsPage extends StatefulWidget {
  const PassengerTripsPage({
    super.key,
    this.loadTrips,
    this.initialTrips = const [],
    this.onTripPressed,
    this.onCreatePressed,
    this.locationService,
  });

  final LoadPassengerTrips? loadTrips;
  final List<PassengerTrip> initialTrips;
  final ValueChanged<PassengerTrip>? onTripPressed;
  final VoidCallback? onCreatePressed;
  final PassengerLocationService? locationService;

  @override
  State<PassengerTripsPage> createState() => _PassengerTripsPageState();
}

class _PassengerTripsPageState extends State<PassengerTripsPage> {
  static const _designSize = Size(375, 812);
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondary = Color(0xFF61636B);
  static const _divider = Color(0xFFE4E5E6);

  String _vehicleType = 'car';
  PassengerTripFilter _filter = PassengerTripFilter.empty;
  late List<PassengerTrip> _trips;
  bool _isLoading = false;
  bool _locationPromptSeen = false;
  String? _error;

  PassengerLocationService get _locationService =>
      widget.locationService ?? const GeolocatorPassengerLocationService();

  @override
  void initState() {
    super.initState();
    _trips = widget.initialTrips;
    if (widget.loadTrips != null) _load();
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
                    _TripsHeader(
                      filterActive: _filter.isActive,
                      onFilterPressed: _openFilters,
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 124,
                      child: _VehicleSwitch(
                        selected: _vehicleType,
                        onChanged: _changeVehicle,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 192,
                      bottom: 69,
                      child: _buildContent(),
                    ),
                    _PassengerTabBar(onCreatePressed: widget.onCreatePressed),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 3),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Не удалось загрузить поездки',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_trips.isEmpty) return const _EmptyTrips();
    return ListView.separated(
      key: const ValueKey('passenger-trip-list'),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return _PassengerTripCard(
          trip: trip,
          onTap: () => widget.onTripPressed?.call(trip),
        );
      },
    );
  }

  Future<void> _load() async {
    final loader = widget.loadTrips;
    if (loader == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final trips = await loader(_vehicleType, _filter);
      if (!mounted) return;
      setState(() => _trips = trips);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'load_failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeVehicle(String value) {
    if (_vehicleType == value) return;
    setState(() {
      _vehicleType = value;
      if (widget.loadTrips == null) {
        _trips = widget.initialTrips
            .where((trip) => trip.vehicleType == value)
            .toList(growable: false);
      }
    });
    if (widget.loadTrips != null) _load();
  }

  Future<void> _openFilters() async {
    if (!_locationPromptSeen && !_filter.isActive) {
      final choice = await showLocationAccessDialog(context);
      if (!mounted || choice == null) return;
      _locationPromptSeen = true;
      if (choice == LocationAccessChoice.allow) {
        final coordinates = await _locationService.requestCurrentPosition();
        if (!mounted) return;
        if (coordinates != null) {
          _applyFilter(
            PassengerTripFilter.nearby(
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Введите города вручную')),
          );
      }
    }
    await _openManualFilters();
  }

  Future<void> _openManualFilters() async {
    final result = await showPassengerTripFilterSheet(
      context,
      initialFilter: _filter,
    );
    if (!mounted || result == null) return;
    _applyFilter(result);
  }

  void _applyFilter(PassengerTripFilter filter) {
    setState(() => _filter = filter);
    if (widget.loadTrips != null) _load();
  }
}

class _TripsHeader extends StatelessWidget {
  const _TripsHeader({
    required this.filterActive,
    required this.onFilterPressed,
  });

  final bool filterActive;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 54,
      height: 60,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _PassengerTripsPageState._divider),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 56),
            const Expanded(
              child: Text(
                'Поездки',
                key: ValueKey('passenger-trips-title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _PassengerTripsPageState._text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Stack(
                children: [
                  Center(
                    child: Material(
                      color: const Color(0xFFF7F7F8),
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const ValueKey('passenger-filter'),
                        customBorder: const CircleBorder(),
                        onTap: onFilterPressed,
                        child: SizedBox.square(
                          dimension: 40,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/passenger/filter.svg',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (filterActive)
                    Positioned(
                      top: 10,
                      right: 13,
                      child: Container(
                        key: const ValueKey('passenger-filter-active'),
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEB4244),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleSwitch extends StatelessWidget {
  const _VehicleSwitch({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: _PassengerTripsPageState._divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _VehicleButton(
            key: const ValueKey('passenger-cars-tab'),
            label: 'Автомобили',
            selected: selected == 'car',
            onTap: () => onChanged('car'),
          ),
          _VehicleButton(
            key: const ValueKey('passenger-buses-tab'),
            label: 'Автобусы',
            selected: selected == 'bus',
            onTap: () => onChanged('bus'),
          ),
        ],
      ),
    );
  }
}

class _VehicleButton extends StatelessWidget {
  const _VehicleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? _PassengerTripsPageState._primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : _PassengerTripsPageState._secondary,
                fontSize: 13,
                height: 1.38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: const ValueKey('passenger-trips-empty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/passenger/empty_trips.png',
            width: 90,
            height: 80,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          const Text(
            'Здесь ещё нет заказов',
            style: TextStyle(
              color: _PassengerTripsPageState._text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.29,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Станьте первым — создайте поездку или\nпроверьте чуть позже',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0x7F0C0C0C),
              fontSize: 15,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerTripCard extends StatelessWidget {
  const _PassengerTripCard({required this.trip, required this.onTap});

  final PassengerTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('passenger-trip-${trip.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: trip.isRegistrationOpen
              ? _PassengerTripsPageState._primary
              : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(url: trip.driverAvatarUrl, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.driverName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.33,
                          ),
                        ),
                        Row(
                          children: [
                            _AssetIcon('star.svg', size: 14),
                            const SizedBox(width: 8),
                            Text(
                              trip.driverRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: _PassengerTripsPageState._secondary,
                                fontSize: 13,
                              ),
                            ),
                            if (trip.distanceKm != null) ...[
                              const SizedBox(width: 8),
                              _AssetIcon('map_point.svg', size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${trip.distanceKm!.toStringAsFixed(1)} км',
                                style: const TextStyle(
                                  color: _PassengerTripsPageState._secondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _TripBadge(top: trip.driverRating >= 4.5),
                ],
              ),
              const SizedBox(height: 12),
              _RouteLine(
                from: trip.boardAddress,
                to: trip.alightAddress,
                stopsCount: trip.stopsCount,
              ),
              const SizedBox(height: 8),
              _TripTags(
                extras: trip.extras,
                acceptsParcels: trip.acceptsParcels,
                seats: trip.seatsAvailable,
              ),
              if (trip.isRegistrationOpen) ...[
                const SizedBox(height: 10),
                const Text(
                  'Идёт регистрация пассажиров',
                  key: ValueKey('passenger-registration-open'),
                  style: TextStyle(
                    color: _PassengerTripsPageState._primary,
                    fontSize: 15,
                    height: 1.33,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _PassengerTripsPageState._divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _AssetIcon('calendar.svg', size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatDateTime(trip.departureAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${trip.price} ₽',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/чел',
                      style: TextStyle(
                        color: _PassengerTripsPageState._secondary,
                        fontSize: 13,
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
}

class _TripBadge extends StatelessWidget {
  const _TripBadge({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: _PassengerTripsPageState._primary),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _AssetIcon(top ? 'star.svg' : 'clock.svg', size: 14),
          const SizedBox(width: 4),
          Text(top ? 'Топ' : 'Ближайший', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.from,
    required this.to,
    required this.stopsCount,
  });

  final String from;
  final String to;
  final int stopsCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteAddress(text: from, filled: true),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _PassengerTripsPageState._text,
                ),
                const SizedBox(width: 13),
                Text(
                  '$stopsCount ${_stopWord(stopsCount)}',
                  style: const TextStyle(
                    color: Color(0x7F0C0C0C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        _RouteAddress(text: to, filled: false),
      ],
    );
  }
}

class _RouteAddress extends StatelessWidget {
  const _RouteAddress({required this.text, required this.filled});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: filled ? _PassengerTripsPageState._text : Colors.transparent,
            border: filled
                ? null
                : Border.all(color: _PassengerTripsPageState._text, width: 2),
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
}

class _TripTags extends StatelessWidget {
  const _TripTags({
    required this.extras,
    required this.acceptsParcels,
    required this.seats,
  });

  final List<String> extras;
  final bool acceptsParcels;
  final int seats;

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    if (extras.contains('pets')) {
      tags.add(const _Tag(icon: 'paw.svg', label: 'С животными'));
    }
    if (extras.contains('luggage')) {
      tags.add(const _Tag(icon: 'bag.svg', label: 'С багажом'));
    }
    if (extras.contains('child_seat')) {
      tags.add(const _Tag(icon: 'baby.svg', label: 'Дет. кресло'));
    }
    if (acceptsParcels) {
      tags.add(const _Tag(icon: 'parcel.svg', label: 'Посылка S, M'));
    }
    tags.add(
      _Tag(
        icon: 'nav_profile.svg',
        label: '$seats ${seats == 1 ? 'место' : 'места'}',
      ),
    );
    return Wrap(spacing: 10, runSpacing: 4, children: tags);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _AssetIcon(icon, size: 14),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = _mediaUrl(url);
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: resolved == null
            ? const ColoredBox(
                color: _PassengerTripsPageState._divider,
                child: Icon(
                  Icons.person,
                  color: _PassengerTripsPageState._secondary,
                ),
              )
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: _PassengerTripsPageState._divider,
                  child: Icon(
                    Icons.person,
                    color: _PassengerTripsPageState._secondary,
                  ),
                ),
              ),
      ),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  const _AssetIcon(this.name, {required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: SvgPicture.asset('assets/icons/passenger/$name'),
  );
}

class _PassengerTabBar extends StatelessWidget {
  const _PassengerTabBar({this.onCreatePressed});

  final VoidCallback? onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 69,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _PassengerTripsPageState._background,
          border: Border(
            top: BorderSide(color: _PassengerTripsPageState._divider),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TabItem(
              icon: 'nav_trips.svg',
              label: 'Поездки',
              selected: true,
            ),
            const _TabItem(icon: 'nav_orders.svg', label: 'Мои заказы'),
            Expanded(
              child: Center(
                child: Material(
                  color: _PassengerTripsPageState._primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: const ValueKey('passenger-create'),
                    onTap: onCreatePressed,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(child: _AssetIcon('nav_add.svg', size: 24)),
                    ),
                  ),
                ),
              ),
            ),
            const _TabItem(icon: 'nav_chat.svg', label: 'Чаты'),
            const _TabItem(icon: 'nav_profile.svg', label: 'Профиль'),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final String icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AssetIcon(icon, size: 24),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? _PassengerTripsPageState._text
                    : _PassengerTripsPageState._secondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatDateTime(DateTime value) {
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
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]}, ${local.hour}:$minute';
}

String _stopWord(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'остановка';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'остановки';
  }
  return 'остановок';
}

String? _mediaUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${AppConfig.apiBaseUrl}$value';
}

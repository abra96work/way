import 'package:flutter/material.dart';

import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';

/// "Новый заказ", step 1 of 4: the vehicle type of the trip.
class TripTypeStepPage extends StatefulWidget {
  const TripTypeStepPage({
    super.key,
    required this.onNext,
    this.initialType = VehicleType.car,
    this.onBack,
  });

  final VehicleType initialType;
  final ValueChanged<VehicleType> onNext;
  final VoidCallback? onBack;

  @override
  State<TripTypeStepPage> createState() => _TripTypeStepPageState();
}

class _TripTypeStepPageState extends State<TripTypeStepPage> {
  late VehicleType _selected = widget.initialType;

  @override
  Widget build(BuildContext context) {
    return NewTripScaffold(
      step: 1,
      onBack: widget.onBack,
      onNext: () => widget.onNext(_selected),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Тип заказа', style: DriverText.label),
          const SizedBox(height: 12),
          _VehicleTypeCard(
            key: const ValueKey('trip-type-car'),
            title: 'Автомобиль',
            subtitle: 'Легковая машина, до 8 пассажиров',
            image: 'assets/images/driver/vehicle_car.png',
            selected: _selected == VehicleType.car,
            onTap: () => setState(() => _selected = VehicleType.car),
          ),
          const SizedBox(height: 12),
          _VehicleTypeCard(
            key: const ValueKey('trip-type-bus'),
            title: 'Автобус',
            subtitle: 'Маршрутка или автобус, до 60 мест',
            image: 'assets/images/driver/vehicle_bus.png',
            selected: _selected == VehicleType.bus,
            onTap: () => setState(() => _selected = VehicleType.bus),
          ),
        ],
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  const _VehicleTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? DriverColors.primary : Colors.transparent,
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$title. $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: DriverColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // At least the Figma height; grows if the text wraps (large font).
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 108),
            child: Stack(
              children: [
                // The vehicle sticks out of the card's right edge, as in Figma.
                Positioned(
                  right: -16,
                  top: 8,
                  bottom: -4,
                  width: 156,
                  child: Image.asset(
                    image,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    excludeFromSemantics: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RadioDot(selected: selected),
                      const SizedBox(width: 12),
                      Flexible(
                        child: ConstrainedBox(
                          // Text column is 180 wide in Figma; the vehicle sits to the right.
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: DriverText.cardTitle),
                              const SizedBox(height: 8),
                              Text(subtitle, style: DriverText.body),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DriverColors.primary, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: selected ? 13.33 : 0,
        height: selected ? 13.33 : 0,
        decoration: const BoxDecoration(
          color: DriverColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

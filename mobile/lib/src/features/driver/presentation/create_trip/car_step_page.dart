import 'package:flutter/material.dart';

import '../../domain/driver_car.dart';
import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';
import '../widgets/price_summary.dart';

/// "Новый заказ", step 4 of 6: the car.
class CarStepPage extends StatefulWidget {
  const CarStepPage({
    super.key,
    required this.draft,
    required this.loadCars,
    required this.onNext,
    this.onAddCar,
    this.onBack,
  });

  final TripDraft draft;
  final Future<List<DriverCar>> Function() loadCars;

  final VoidCallback onNext;

  /// Opens "add a car"; the list reloads when it completes.
  final Future<void> Function()? onAddCar;
  final VoidCallback? onBack;

  @override
  State<CarStepPage> createState() => _CarStepPageState();
}

class _CarStepPageState extends State<CarStepPage> {
  late Future<List<DriverCar>> _cars = widget.loadCars();

  TripDraft get draft => widget.draft;

  Future<void> _addCar() async {
    await widget.onAddCar?.call();
    if (!mounted) return;
    setState(() {
      _cars = widget.loadCars();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => FutureBuilder<List<DriverCar>>(
        future: _cars,
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <DriverCar>[];
          final cars = all
              .where((c) => c.vehicleType == draft.vehicleType)
              .toList();
          final selected = cars.where((c) => c.id == draft.carId).firstOrNull;
          final canSubmit = selected != null && selected.seats >= draft.seats;
          return NewTripScaffold(
            step: 4,
            onBack: widget.onBack,
            onNext: canSubmit ? widget.onNext : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((draft.fullPrice ?? 0) > 0) ...[
                  PriceSummary(driverPrice: draft.fullPrice!),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Автомобиль', style: DriverText.label),
                      ),
                      if (cars.isNotEmpty && widget.onAddCar != null)
                        _AddCarButton(
                          key: const ValueKey('car-add-header'),
                          filled: false,
                          onPressed: _addCar,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: DriverColors.primary,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  _Message(
                    title: 'Не удалось загрузить автомобили',
                    text: 'Проверьте интернет и попробуйте ещё раз',
                    action: TextButton(
                      onPressed: () => setState(() {
                        _cars = widget.loadCars();
                      }),
                      child: const Text('Повторить'),
                    ),
                  )
                else if (cars.isEmpty)
                  _Message(
                    key: const ValueKey('car-empty'),
                    icon: true,
                    title: all.isEmpty
                        ? 'Нет добавленных авто'
                        : draft.vehicleType == VehicleType.bus
                        ? 'Нет добавленных автобусов'
                        : 'Нет добавленных легковых авто',
                    text: 'Чтобы создать поездку, добавьте автомобиль',
                    action: widget.onAddCar == null
                        ? null
                        : _AddCarButton(
                            key: const ValueKey('car-add-empty'),
                            filled: true,
                            onPressed: _addCar,
                          ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DriverColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        for (final car in cars) ...[
                          _CarTile(
                            key: ValueKey('car-${car.id}'),
                            car: car,
                            selected: car.id == draft.carId,
                            tooFewSeats: car.seats < draft.seats,
                            passengers: draft.seats,
                            onTap: () => draft.car = car,
                          ),
                          if (car != cars.last) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddCarButton extends StatelessWidget {
  const _AddCarButton({
    super.key,
    required this.filled,
    required this.onPressed,
  });

  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    const text = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.33,
    );
    const padding = EdgeInsets.symmetric(horizontal: 12);
    return SizedBox(
      height: 32,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: DriverColors.primary,
                shape: shape,
                padding: padding,
                textStyle: text,
              ),
              child: const Text('Добавить авто'),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: DriverColors.primary,
                side: const BorderSide(color: DriverColors.primary),
                shape: shape,
                padding: padding,
                textStyle: text,
              ),
              child: const Text('Добавить авто'),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.title,
    required this.text,
    this.action,
    this.icon = false,
  });

  final String title;
  final String text;
  final Widget? action;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: DriverColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (icon) ...[
            const Icon(
              Icons.directions_car_filled_outlined,
              size: 64,
              color: DriverColors.divider,
            ),
            const SizedBox(height: 8),
          ],
          Text(title, textAlign: TextAlign.center, style: DriverText.cardTitle),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: DriverText.body.copyWith(color: const Color(0xFF95969C)),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

class _CarTile extends StatelessWidget {
  const _CarTile({
    super.key,
    required this.car,
    required this.selected,
    required this.tooFewSeats,
    required this.passengers,
    required this.onTap,
  });

  final DriverCar car;
  final bool selected;
  final bool tooFewSeats;
  final int passengers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (car.plate != null && car.plate!.isNotEmpty) car.plate!,
      seatsLabel(car.seats),
    ].join(' • ');
    final enabled = !tooFewSeats;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      enabled: enabled,
      button: true,
      label: '${car.title}, $details',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: selected ? const Color(0xFFE6F6EB) : DriverColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? DriverColors.primary : DriverColors.divider,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _Thumb(url: car.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(car.title, style: DriverText.label),
                        const SizedBox(height: 2),
                        Text(
                          enabled
                              ? details
                              : '$details · нужно мест: $passengers',
                          style: DriverText.body.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Radio(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: DriverColors.background,
      child: Icon(
        Icons.directions_car_rounded,
        color: DriverColors.secondaryText,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: 40,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

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
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: DriverColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

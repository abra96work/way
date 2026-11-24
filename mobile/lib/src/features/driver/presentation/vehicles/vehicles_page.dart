import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_car.dart';
import '../widgets/driver_style.dart';

/// "Транспортные средства": the driver's cars (`GET /cars`).
class VehiclesPage extends StatefulWidget {
  const VehiclesPage({
    super.key,
    required this.loadCars,
    this.onAddCar,
    this.onOpenCar,
    this.onBack,
  });

  final Future<List<DriverCar>> Function() loadCars;

  /// Opens "add a vehicle"; the list reloads when it completes.
  final Future<void> Function()? onAddCar;

  /// Opens a vehicle's card; the list reloads when it completes.
  final Future<void> Function(DriverCar car)? onOpenCar;
  final VoidCallback? onBack;

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  late Future<List<DriverCar>> _cars = widget.loadCars();

  void _reload() => setState(() {
    _cars = widget.loadCars();
  });

  Future<void> _add() async {
    await widget.onAddCar?.call();
    if (mounted) _reload();
  }

  Future<void> _open(DriverCar car) async {
    await widget.onOpenCar?.call(car);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onBack: widget.onBack),
              const Divider(
                height: 1,
                thickness: 1,
                color: DriverColors.divider,
              ),
              Expanded(
                child: FutureBuilder<List<DriverCar>>(
                  future: _cars,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: DriverColors.primary,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _Centered(
                        title: 'Не удалось загрузить транспорт',
                        text: 'Проверьте интернет и попробуйте ещё раз',
                        action: TextButton(
                          onPressed: _reload,
                          child: const Text('Повторить'),
                        ),
                      );
                    }
                    final cars = snapshot.data!;
                    if (cars.isEmpty) {
                      return _Centered(
                        key: const ValueKey('vehicles-empty'),
                        image: true,
                        title: 'У вас еще нет транспортного средства',
                        text:
                            'Добавьте информацию о ТС и берите или '
                            'создавайте заказы',
                        action: _AddButton(
                          key: const ValueKey('vehicles-add-empty'),
                          onPressed: widget.onAddCar == null ? null : _add,
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            color: DriverColors.primary,
                            onRefresh: () async {
                              _reload();
                              await _cars.catchError((_) => <DriverCar>[]);
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.only(
                                top: 20,
                                bottom: 16,
                              ),
                              itemCount: cars.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) => _VehicleCard(
                                car: cars[i],
                                onTap: widget.onOpenCar == null
                                    ? null
                                    : () => _open(cars[i]),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              key: const ValueKey('vehicles-add'),
                              onPressed: widget.onAddCar == null ? null : _add,
                              style: FilledButton.styleFrom(
                                backgroundColor: DriverColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: DriverText.label,
                              ),
                              child: const Text('Добавить ТС'),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              'Транспортные средства',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DriverText.title,
            ),
          ),
          Positioned(
            left: 8,
            child: Material(
              color: const Color(0xFFF7F7F8),
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey('vehicles-back'),
                customBorder: const CircleBorder(),
                onTap: onBack ?? () => Navigator.maybePop(context),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: DriverColors.text,
                    semanticLabel: 'Назад',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    super.key,
    required this.title,
    required this.text,
    this.action,
    this.image = false,
  });

  final String title;
  final String text;
  final Widget? action;
  final bool image;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image) ...[
              Image.asset(
                'assets/images/driver/no_vehicle.png',
                width: 90,
                height: 80,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 90,
                  height: 80,
                  child: Icon(
                    Icons.badge_outlined,
                    size: 64,
                    color: Color(0xFFB9BABD),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: DriverText.cardTitle,
            ),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, style: DriverText.body),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.onPressed});

  /// `null` while adding vehicles is not available yet.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 14),
      label: const Text('Добавить ТС'),
      style: FilledButton.styleFrom(
        backgroundColor: DriverColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.38,
        ),
      ),
    );
  }
}

/// A vehicle in the list: photo, model, plate and seats, chevron.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.car, this.onTap});

  final DriverCar car;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (car.plate != null && car.plate!.isNotEmpty) car.plate!,
      seatsLabel(car.seats),
    ].join(' • ');
    const placeholder = ColoredBox(
      color: DriverColors.background,
      child: Icon(
        Icons.directions_car_rounded,
        size: 22,
        color: DriverColors.secondaryText,
      ),
    );
    return Material(
      color: DriverColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('vehicle-${car.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 42,
                  child: car.photoUrl == null
                      ? placeholder
                      : Image.network(
                          car.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.title,
                      style: const TextStyle(
                        color: DriverColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(details, style: DriverText.body),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DriverColors.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

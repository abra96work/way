import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TripRole { driver, passenger }

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key, this.onRoleSelected});

  final ValueChanged<TripRole>? onRoleSelected;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  static const _primary = Color(0xFF1EB74D);
  static const _textColor = Color(0xFF0C0C0C);

  TripRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFEDEDED),
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = (constraints.maxHeight * 0.48)
                  .clamp(300.0, 390.0)
                  .toDouble();
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: heroHeight,
                    child: const _RoleHero(),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDEDED),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.21,
                              ),
                              children: [
                                TextSpan(text: 'Добро пожаловать\nв '),
                                TextSpan(
                                  text: 'Путь',
                                  style: TextStyle(color: _primary),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'От чьего лица вы хотите\nсоздать поездку?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: _RoleCard(
                                  semanticsKey: const ValueKey('driver-role'),
                                  label: 'Водитель',
                                  imagePath: 'assets/images/steering_wheel.png',
                                  imageWidth: 74,
                                  imageHeight: 63,
                                  selected: _selectedRole == TripRole.driver,
                                  onTap: () => _selectRole(TripRole.driver),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoleCard(
                                  semanticsKey: const ValueKey(
                                    'passenger-role',
                                  ),
                                  label: 'Пассажир',
                                  imagePath: 'assets/images/driver_seat.png',
                                  imageWidth: 80,
                                  imageHeight: 77,
                                  selected: _selectedRole == TripRole.passenger,
                                  onTap: () => _selectRole(TripRole.passenger),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _selectRole(TripRole role) async {
    if (_selectedRole != role) {
      setState(() => _selectedRole = role);
    }
    if (widget.onRoleSelected == null) return;

    // Оставляем выбранное состояние видимым перед сменой экрана.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) widget.onRoleSelected?.call(role);
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.61,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _RoleSelectionPageState._primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 26,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_marker.png',
                key: const ValueKey('role-header-logo'),
                width: 42,
                height: 42,
                fit: BoxFit.contain,
                semanticLabel: 'Логотип приложения Путь',
              ),
              const SizedBox(width: 10),
              const Text(
                'Путь',
                style: TextStyle(
                  color: Color(0xFFF3F3F3),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 105,
          bottom: 0,
          child: Image.asset(
            'assets/images/onboarding_car.png',
            key: const ValueKey('role-car-image'),
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            semanticLabel: 'Автомобиль для совместной поездки',
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.semanticsKey,
    required this.label,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.selected,
    required this.onTap,
  });

  final Key semanticsKey;
  final String label;
  final String imagePath;
  final double imageWidth;
  final double imageHeight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFFF3F3F3)
        : _RoleSelectionPageState._textColor;

    return Semantics(
      key: semanticsKey,
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? _RoleSelectionPageState._primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 132,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    imagePath,
                    width: imageWidth,
                    height: imageHeight,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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

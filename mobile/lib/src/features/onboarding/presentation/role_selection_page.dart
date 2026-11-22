import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum TripRole { driver, passenger }

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  static const _designSize = Size(375, 812);
  static const _primary = Color(0xFF1EB74D);
  static const _textColor = Color(0xFF0C0C0C);

  TripRole _selectedRole = TripRole.driver;

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
        body: ColoredBox(
          color: Colors.white,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(
                size: _designSize,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 222,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 132,
                      top: 60,
                      width: 50,
                      height: 50,
                      child: Image.asset(
                        'assets/images/logo_marker.png',
                        key: const ValueKey('role-header-logo'),
                        fit: BoxFit.cover,
                        semanticLabel: 'Логотип приложения Путь',
                      ),
                    ),
                    const Positioned(
                      left: 192,
                      top: 70,
                      child: Text(
                        'Путь',
                        style: TextStyle(
                          color: Color(0xFFF3F3F3),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 145,
                      width: 375,
                      height: 273,
                      child: Image.asset(
                        'assets/images/onboarding_car.png',
                        key: const ValueKey('role-car-image'),
                        fit: BoxFit.cover,
                        semanticLabel: 'Автомобиль для совместной поездки',
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 455,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEDED),
                          border: Border.all(
                            color: const Color(0xFFF6F6F7),
                            width: 3,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 16,
                              top: 32,
                              width: 343,
                              child: Text.rich(
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
                            ),
                            const Positioned(
                              left: 16,
                              top: 108,
                              width: 343,
                              child: Text(
                                'От чьего лица вы хотите\nсоздать поездку?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 13,
                              top: 188,
                              child: Row(
                                children: [
                                  _RoleCard(
                                    semanticsKey: const ValueKey('driver-role'),
                                    label: 'Водитель',
                                    imagePath:
                                        'assets/images/steering_wheel.png',
                                    imageWidth: 74,
                                    imageHeight: 63,
                                    selected: _selectedRole == TripRole.driver,
                                    onTap: () => _selectRole(TripRole.driver),
                                  ),
                                  const SizedBox(width: 9),
                                  _RoleCard(
                                    semanticsKey: const ValueKey(
                                      'passenger-role',
                                    ),
                                    label: 'Пассажир',
                                    imagePath: 'assets/images/driver_seat.png',
                                    imageWidth: 80,
                                    imageHeight: 77,
                                    selected:
                                        _selectedRole == TripRole.passenger,
                                    onTap: () =>
                                        _selectRole(TripRole.passenger),
                                  ),
                                ],
                              ),
                            ),
                            const Positioned(
                              left: 118,
                              bottom: 8,
                              width: 139,
                              height: 5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _textColor,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(100),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  void _selectRole(TripRole role) {
    if (_selectedRole == role) return;
    setState(() => _selectedRole = role);
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
        color: selected
            ? _RoleSelectionPageState._primary
            : const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 167,
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

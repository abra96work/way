import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PassengerRolePage extends StatelessWidget {
  const PassengerRolePage({
    super.key,
    required this.onBack,
    required this.onDriver,
  });

  final VoidCallback onBack;
  final VoidCallback onDriver;

  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);

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
      key: const ValueKey('passenger-role-page'),
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  _CircleButton(icon: Icons.chevron_left, onTap: onBack),
                  const Expanded(
                    child: Text(
                      'Выберите роль',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const _CircleButton(icon: Icons.more_horiz),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                children: [
                  _RoleRow(
                    key: const ValueKey('passenger-role-driver'),
                    label: 'Водитель',
                    selected: false,
                    onTap: onDriver,
                  ),
                  const SizedBox(height: 14),
                  const _RoleRow(label: 'Пассажир', selected: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PassengerRolePage._primary, width: 2),
          ),
          child: selected
              ? Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: PassengerRolePage._primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 15)),
      ],
    ),
  );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(dimension: 40, child: Icon(icon, size: 21)),
    ),
  );
}

import 'package:flutter/material.dart';

import 'driver_style.dart';

/// Tabs of the driver's bottom bar; [create] is the green "+" button.
enum DriverTab { home, orders, create, chats, profile }

/// Bottom bar of the driver screens: Главная, Мои заказы, "+", Чаты, Профиль.
class DriverNavBar extends StatelessWidget {
  const DriverNavBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final DriverTab current;
  final ValueChanged<DriverTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DriverColors.background,
        border: Border(top: BorderSide(color: DriverColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _item(DriverTab.home, Icons.home_outlined, 'Главная'),
              _item(
                DriverTab.orders,
                Icons.receipt_long_outlined,
                'Мои заказы',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  button: true,
                  label: 'Новый заказ',
                  child: Material(
                    color: DriverColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const ValueKey('nav-create'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(DriverTab.create),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.add_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              _item(DriverTab.chats, Icons.chat_bubble_outline_rounded, 'Чаты'),
              _item(DriverTab.profile, Icons.person_rounded, 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(DriverTab tab, IconData icon, String label) {
    final active = tab == current;
    final color = active ? DriverColors.text : DriverColors.secondaryText;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          key: ValueKey('nav-${tab.name}'),
          onTap: () => onSelect(tab),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PassengerNavTab { trips, orders, chats, profile }

class PassengerNavBar extends StatelessWidget {
  const PassengerNavBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  static const _background = Color(0xFFF1F2F3);
  static const _text = Color(0xFF0C0C0C);
  static const _secondary = Color(0xFF61636B);
  static const _divider = Color(0xFFE4E5E6);

  final PassengerNavTab current;
  final ValueChanged<PassengerNavTab> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _background,
      border: Border(top: BorderSide(color: _divider)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 69,
        child: Row(
          children: [
            _item(PassengerNavTab.trips, 'nav_trips.svg', 'Поездки'),
            _item(PassengerNavTab.orders, 'nav_orders.svg', 'Мои заказы'),
            _item(PassengerNavTab.chats, 'nav_chat.svg', 'Чаты'),
            _item(PassengerNavTab.profile, 'nav_profile.svg', 'Профиль'),
          ],
        ),
      ),
    ),
  );

  Widget _item(PassengerNavTab tab, String icon, String label) {
    final selected = current == tab;
    final color = selected ? _text : _secondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: ValueKey('passenger-nav-${tab.name}'),
          onTap: () => onSelect(tab),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/passenger/$icon',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 10),
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

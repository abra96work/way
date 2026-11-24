import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/passenger_profile.dart';

enum PassengerProfileSection {
  role,
  personal,
  savedRoutes,
  history,
  complaints,
  notifications,
  payment,
  faq,
  about,
}

class PassengerProfilePage extends StatefulWidget {
  const PassengerProfilePage({
    super.key,
    required this.loadProfile,
    required this.onOpen,
    required this.onLogout,
    this.loadUnreadNotifications,
    this.onTrips,
    this.onOrders,
    this.onChats,
  });

  final Future<PassengerProfile> Function() loadProfile;
  final Future<int> Function()? loadUnreadNotifications;
  final ValueChanged<PassengerProfileSection> onOpen;
  final Future<void> Function() onLogout;
  final VoidCallback? onTrips;
  final VoidCallback? onOrders;
  final VoidCallback? onChats;

  @override
  State<PassengerProfilePage> createState() => _PassengerProfilePageState();
}

class _PassengerProfilePageState extends State<PassengerProfilePage> {
  static const _background = Color(0xFFF1F2F3);
  static const _primary = Color(0xFF1EB74D);
  static const _text = Color(0xFF0C0C0C);
  static const _secondary = Color(0x7F0C0C0C);
  static const _divider = Color(0xFFE4E5E6);

  late Future<PassengerProfile> _profile = widget.loadProfile();
  late Future<int> _unread =
      widget.loadUnreadNotifications?.call().catchError((_) => 0) ??
      Future.value(0);

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
      key: const ValueKey('passenger-profile-page'),
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Мой профиль',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Divider(height: 1, color: _divider),
            Expanded(
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  children: [
                    FutureBuilder<PassengerProfile>(
                      future: _profile,
                      builder: (context, snapshot) => _ProfileHeader(
                        profile: snapshot.data,
                        failed: snapshot.hasError,
                        onRetry: _reload,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ProfileRow(
                      key: const ValueKey('passenger-profile-role'),
                      icon: Icons.badge_outlined,
                      title: 'Перейти в режим водителя',
                      onTap: () => widget.onOpen(PassengerProfileSection.role),
                    ),
                    _ProfileRow(
                      key: const ValueKey('passenger-profile-personal'),
                      icon: Icons.person_outline,
                      title: 'Личные данные',
                      subtitle: 'Имя, фото',
                      onTap: () =>
                          widget.onOpen(PassengerProfileSection.personal),
                    ),
                    _ProfileRow(
                      icon: Icons.map_outlined,
                      title: 'Сохраненные маршруты',
                      subtitle: 'Избранные адреса и поездки',
                      onTap: () =>
                          widget.onOpen(PassengerProfileSection.savedRoutes),
                    ),
                    _ProfileRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'История заказов',
                      subtitle: 'Прошлые поездки и детали',
                      onTap: () =>
                          widget.onOpen(PassengerProfileSection.history),
                    ),
                    _ProfileRow(
                      icon: Icons.report_gmailerrorred_outlined,
                      title: 'Жалобы',
                      subtitle: 'Список жалоб',
                      onTap: () =>
                          widget.onOpen(PassengerProfileSection.complaints),
                    ),
                    FutureBuilder<int>(
                      future: _unread,
                      builder: (context, snapshot) => _ProfileRow(
                        icon: Icons.notifications_none,
                        title: 'Уведомления',
                        subtitle: 'Push-уведомления',
                        badge: snapshot.data ?? 0,
                        onTap: () => widget.onOpen(
                          PassengerProfileSection.notifications,
                        ),
                      ),
                    ),
                    _ProfileRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Способ оплаты',
                      subtitle: 'Карты и способы оплаты',
                      onTap: () =>
                          widget.onOpen(PassengerProfileSection.payment),
                    ),
                    _ProfileRow(
                      icon: Icons.help_outline,
                      title: 'Частые вопросы',
                      onTap: () => widget.onOpen(PassengerProfileSection.faq),
                    ),
                    _ProfileRow(
                      icon: Icons.info_outline,
                      title: 'О приложении',
                      subtitle: 'Версия, информация',
                      onTap: () => widget.onOpen(PassengerProfileSection.about),
                    ),
                    const SizedBox(height: 2),
                    FilledButton.icon(
                      key: const ValueKey('passenger-profile-logout'),
                      onPressed: _confirmLogout,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 17),
                      label: const Text('Выйти из аккаунта'),
                    ),
                  ],
                ),
              ),
            ),
            _ProfileBottomBar(
              onTrips: widget.onTrips,
              onOrders: widget.onOrders,
              onChats: widget.onChats,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _reload() async {
    final profile = widget.loadProfile();
    final unread =
        widget.loadUnreadNotifications?.call().catchError((_) => 0) ??
        Future.value(0);
    setState(() {
      _profile = profile;
      _unread = unread;
    });
    await profile;
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (context) => Dialog(
        key: const ValueKey('passenger-logout-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Выйдите из аккаунта?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              key: const ValueKey('passenger-logout-confirm'),
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: _text,
              ),
              child: const Text(
                'Выйти',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: _text,
              ),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await widget.onLogout();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.failed,
    required this.onRetry,
  });

  final PassengerProfile? profile;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Column(
        children: [
          const CircleAvatar(radius: 42, child: Icon(Icons.person)),
          const Text('Не удалось загрузить профиль'),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      );
    }
    final value = profile;
    return Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFFE4E5E6),
          backgroundImage: value?.avatarUrl == null
              ? null
              : NetworkImage(value!.avatarUrl!),
          child: value?.avatarUrl == null
              ? const Icon(Icons.person, size: 42, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          value?.displayName ?? '',
          key: const ValueKey('passenger-profile-name'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        if (value != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Color(0xFFFFB800), size: 15),
              const SizedBox(width: 3),
              Text(
                value.reviewsCount == 0
                    ? '5,0 · нет отзывов'
                    : '${value.ratingLabel} · '
                          '${passengerTripsLabel(value.completedTrips)}',
                key: const ValueKey('passenger-profile-rating'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFF1F2F3),
                child: Icon(icon, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: _PassengerProfilePageState._secondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _PassengerProfilePageState._primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _PassengerProfilePageState._divider,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, size: 20),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileBottomBar extends StatelessWidget {
  const _ProfileBottomBar({this.onTrips, this.onOrders, this.onChats});

  final VoidCallback? onTrips;
  final VoidCallback? onOrders;
  final VoidCallback? onChats;

  @override
  Widget build(BuildContext context) => Container(
    height: 69,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE4E5E6))),
    ),
    child: Row(
      children: [
        _nav('nav_trips.svg', 'Главная', onTrips),
        _nav('nav_orders.svg', 'Мои заказы', onOrders),
        _nav('nav_chat.svg', 'Чаты', onChats),
        _nav('nav_profile.svg', 'Профиль', null, selected: true),
      ],
    ),
  );

  Widget _nav(
    String icon,
    String label,
    VoidCallback? onTap, {
    bool selected = false,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            SvgPicture.asset('assets/icons/passenger/$icon', width: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF0C0C0C) : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

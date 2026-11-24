import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_profile.dart';
import '../widgets/driver_nav_bar.dart';
import '../widgets/driver_style.dart';

/// Rows of the driver's profile menu, top to bottom.
enum ProfileSection {
  passengerMode('Перейти в режим пассажира', null, Icons.sync_alt_rounded),
  personalData('Личные данные', 'Имя, фото', Icons.person_outline_rounded),
  vehicles(
    'Транспортные средства',
    'Информация о ТС пользователя',
    Icons.directions_car_outlined,
  ),
  savedRoutes(
    'Сохраненные маршруты',
    'Избранные адреса и поездки',
    Icons.map_outlined,
  ),
  history('История заказов', 'Прошлые поездки и детали', Icons.history_rounded),
  complaints('Жалобы', 'Список жалоб', Icons.report_gmailerrorred_rounded),
  notifications(
    'Уведомления',
    'Push-уведомления',
    Icons.notifications_none_rounded,
  ),
  payment(
    'Способ оплаты',
    'Карты и способы оплаты',
    Icons.account_balance_wallet_outlined,
  ),
  faq('Частые вопросы', null, Icons.help_outline_rounded),
  about('О приложении', 'Версия, информация', Icons.info_outline_rounded);

  const ProfileSection(this.title, this.subtitle, this.icon);

  final String title;
  final String? subtitle;
  final IconData icon;
}

/// "Мой профиль" of the driver: avatar, rating, menu and sign-out.
class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({
    super.key,
    required this.loadProfile,
    required this.onOpen,
    required this.onLogout,
    required this.onTab,
    this.loadUnreadNotifications,
  });

  final Future<DriverProfile> Function() loadProfile;

  /// Unread notifications for the badge; the badge hides on 0 or error.
  final Future<int> Function()? loadUnreadNotifications;
  final ValueChanged<ProfileSection> onOpen;
  final Future<void> Function() onLogout;
  final ValueChanged<DriverTab> onTab;

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  late Future<DriverProfile> _profile = widget.loadProfile();
  late final Future<int> _unread =
      widget.loadUnreadNotifications?.call().catchError((_) => 0) ??
      Future.value(0);

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Чтобы вернуться, нужно будет снова войти по номеру телефона.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const ValueKey('logout-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        bottomNavigationBar: DriverNavBar(
          current: DriverTab.profile,
          onSelect: widget.onTab,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 60,
                child: Center(
                  child: Text('Мой профиль', style: DriverText.title),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: DriverColors.divider,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: DriverColors.primary,
                  onRefresh: () async {
                    final next = widget.loadProfile();
                    setState(() => _profile = next);
                    await next.catchError(
                      (_) => const DriverProfile(firstName: ''),
                    );
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      FutureBuilder<DriverProfile>(
                        future: _profile,
                        builder: (context, snapshot) => _Header(
                          profile: snapshot.data,
                          failed: snapshot.hasError,
                          onRetry: () => setState(() {
                            _profile = widget.loadProfile();
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final section in ProfileSection.values) ...[
                        _MenuRow(
                          section: section,
                          badge: section == ProfileSection.notifications
                              ? _unread
                              : null,
                          onTap: () => widget.onOpen(section),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          key: const ValueKey('profile-logout'),
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Выйти из аккаунта'),
                          style: FilledButton.styleFrom(
                            backgroundColor: DriverColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: DriverText.label,
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.profile, required this.failed, required this.onRetry});

  final DriverProfile? profile;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (failed) {
      return Column(
        children: [
          const _Avatar(url: null),
          const SizedBox(height: 8),
          Text('Не удалось загрузить профиль', style: DriverText.body),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      );
    }
    final name = p == null
        ? ''
        : [p.firstName, if (p.lastName != null) p.lastName].join(' ').trim();
    const info = TextStyle(
      color: DriverColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.33,
    );
    return Column(
      children: [
        _Avatar(url: p?.avatarUrl),
        const SizedBox(height: 8),
        Text(
          name,
          key: const ValueKey('profile-name'),
          textAlign: TextAlign.center,
          style: DriverText.title,
        ),
        const SizedBox(height: 2),
        if (p != null)
          Wrap(
            key: const ValueKey('profile-rating'),
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFFFB800),
              ),
              const SizedBox(width: 4),
              Text(p.ratingLabel, style: info),
              // Reviews are not collected in this build: say so instead of
              // a rating that looks earned.
              if (p.reviewsCount == 0) ...[
                const _Dot(),
                Text('нет отзывов', style: info),
              ],
              const _Dot(),
              Text(tripsLabel(p.completedTrips), style: info),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: DriverColors.text,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xFFE4E5E6),
      child: Icon(Icons.person_rounded, size: 48, color: Colors.white),
    );
    return Center(
      child: ClipOval(
        child: SizedBox.square(
          dimension: 96,
          child: url == null
              ? placeholder
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.section, required this.onTap, this.badge});

  final ProfileSection section;
  final VoidCallback onTap;
  final Future<int>? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DriverColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('profile-${section.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: BoxShape.circle,
                ),
                child: Icon(section.icon, size: 24, color: DriverColors.text),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(section.title, style: DriverText.label),
                        ),
                        if (badge != null)
                          FutureBuilder<int>(
                            future: badge,
                            builder: (context, snapshot) {
                              final n = snapshot.data ?? 0;
                              if (n <= 0) return const SizedBox.shrink();
                              return Container(
                                key: const ValueKey('profile-unread'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: DriverColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  n > 99 ? '99+' : '$n',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.18,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    if (section.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(section.subtitle!, style: DriverText.body),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: DriverColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: DriverColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

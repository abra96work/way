import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_car.dart' show seatsLabel;
import '../../domain/driver_trip.dart';
import '../../domain/trip_draft.dart';
import '../widgets/driver_nav_bar.dart';
import '../widgets/driver_style.dart';
import '../widgets/price_summary.dart' show formatRubles;

/// Tabs of "Мои заказы".
enum DriverTripsTab { active, completed }

/// "Мои заказы" of the driver: active (with templates) and finished trips.
class DriverTripsPage extends StatefulWidget {
  const DriverTripsPage({
    super.key,
    required this.loadTrips,
    required this.onCreate,
    required this.onTab,
    this.onOpenTrip,
  });

  /// Trips of a tab: active + drafts, or completed + cancelled.
  final Future<List<DriverTrip>> Function(DriverTripsTab tab) loadTrips;
  final VoidCallback onCreate;
  final ValueChanged<DriverTab> onTab;
  final ValueChanged<DriverTrip>? onOpenTrip;

  @override
  State<DriverTripsPage> createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  DriverTripsTab _tab = DriverTripsTab.active;
  late Future<List<DriverTrip>> _trips = widget.loadTrips(_tab);

  void _select(DriverTripsTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _trips = widget.loadTrips(tab);
    });
  }

  void _reload() => setState(() {
    _trips = widget.loadTrips(_tab);
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        bottomNavigationBar: DriverNavBar(
          current: DriverTab.orders,
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
                  child: Text('Мои заказы', style: DriverText.title),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: DriverColors.divider,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _Tabs(current: _tab, onSelect: _select),
              ),
              Expanded(
                child: FutureBuilder<List<DriverTrip>>(
                  future: _trips,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: DriverColors.primary,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _Empty(
                        title: 'Не удалось загрузить поездки',
                        text: 'Проверьте интернет и попробуйте ещё раз',
                        action: TextButton(
                          onPressed: _reload,
                          child: const Text('Повторить'),
                        ),
                      );
                    }
                    final trips = snapshot.data!;
                    if (trips.isEmpty) {
                      return _tab == DriverTripsTab.active
                          ? _Empty(
                              key: const ValueKey('trips-empty'),
                              image: true,
                              title: 'У вас пока нет поездок',
                              text:
                                  'Создайте поездку, чтобы пассажиры могли '
                                  'найти ваш маршрут',
                              action: FilledButton.icon(
                                key: const ValueKey('trips-create'),
                                onPressed: widget.onCreate,
                                icon: const Icon(Icons.add_rounded, size: 14),
                                label: const Text('Создать заказ'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: DriverColors.primary,
                                  minimumSize: const Size(0, 42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.38,
                                  ),
                                ),
                              ),
                            )
                          : const _Empty(
                              key: ValueKey('trips-empty-completed'),
                              image: true,
                              title: 'Завершённых поездок пока нет',
                              text: 'Здесь появятся прошедшие и отменённые поездки',
                            );
                    }
                    return RefreshIndicator(
                      color: DriverColors.primary,
                      onRefresh: () async {
                        _reload();
                        await _trips.catchError((_) => <DriverTrip>[]);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 20, bottom: 16),
                        itemCount: trips.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => DriverTripCard(
                          trip: trips[i],
                          onTap: widget.onOpenTrip == null
                              ? null
                              : () => widget.onOpenTrip!(trips[i]),
                        ),
                      ),
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.current, required this.onSelect});

  final DriverTripsTab current;
  final ValueChanged<DriverTripsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tab(DriverTripsTab value, String label) {
      final active = value == current;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          child: Material(
            color: active ? DriverColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              key: ValueKey('trips-tab-${value.name}'),
              borderRadius: BorderRadius.circular(4),
              onTap: () => onSelect(value),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF61636B),
                      fontSize: 15,
                      height: 1.33,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        border: Border.all(color: const Color(0xFFC8C8C8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          tab(DriverTripsTab.active, 'Активные'),
          tab(DriverTripsTab.completed, 'Завершенные'),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
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
                'assets/images/driver/no_trips.png',
                width: 90,
                height: 80,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 90,
                  height: 80,
                  child: Icon(
                    Icons.event_busy_outlined,
                    size: 56,
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

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "16 мая, 12:00–15:00" (or just the start when there is no arrival).
String tripWhenLabel(DateTime departure, DateTime? arrival) {
  final day = '${departure.day} ${_months[departure.month - 1]}';
  return arrival == null
      ? '$day, ${_hm(departure)}'
      : '$day, ${_hm(departure)}–${_hm(arrival)}';
}

/// "1 отклик", "3 отклика", "5 откликов".
String requestsLabel(int n) {
  final word = n % 10 == 1 && n % 100 != 11
      ? 'отклик'
      : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
      ? 'отклика'
      : 'откликов';
  return '$n $word';
}

/// A trip in "Мои заказы".
class DriverTripCard extends StatelessWidget {
  const DriverTripCard({super.key, required this.trip, this.onTap});

  final DriverTrip trip;
  final VoidCallback? onTap;

  static const _extraLabels = {
    TripExtraKind.pets: (Icons.pets_outlined, 'С животными'),
    TripExtraKind.childSeat: (Icons.child_friendly_outlined, 'Дет. кресло'),
    TripExtraKind.luggage: (Icons.work_outline_rounded, 'Багаж'),
  };

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final pill = switch (t.status) {
      TripStatus.completed => ('Завершен', DriverColors.primary),
      TripStatus.cancelled => ('Отменен', const Color(0xFFC8C8C8)),
      TripStatus.draft => ('Шаблон', const Color(0xFFC8C8C8)),
      TripStatus.published => null,
    };
    return Material(
      key: ValueKey('trip-card-${t.id}'),
      color: DriverColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.number == null ? 'Заказ' : 'Заказ №${t.number}',
                      style: DriverText.label,
                    ),
                  ),
                  if (pill != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: pill.$2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pill.$1,
                        style: const TextStyle(
                          color: DriverColors.text,
                          fontSize: 13,
                          height: 1.38,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _Route(from: t.stops.first, to: t.stops.last),
              const SizedBox(height: 16),
              if (t.arrivalAt != null) ...[
                _Chip(
                  icon: Icons.schedule_rounded,
                  text: 'Прибытие ~${_hm(t.arrivalAt!)}',
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _Chip(
                    icon: Icons.person_outline_rounded,
                    text: seatsLabel(t.seatsTotal),
                  ),
                  for (final kind in TripExtraKind.values)
                    if (t.extras.containsKey(kind))
                      _Chip(
                        icon: _extraLabels[kind]!.$1,
                        text: _extraLabels[kind]!.$2,
                      ),
                  if (t.parcelSizes.isNotEmpty)
                    _Chip(
                      icon: Icons.inventory_2_outlined,
                      text: t.parcelSizes.length == 1
                          ? 'Посылка ${t.parcelSizes.single.value}'
                          : 'Посылки ${t.parcelSizes.map((s) => s.value).join(', ')}',
                    ),
                ],
              ),
              if (t.requestsCount > 0) ...[
                const SizedBox(height: 12),
                _Requests(count: t.requestsCount, avatars: t.requestAvatars),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: DriverColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: DriverColors.secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tripWhenLabel(t.departureAt, t.arrivalAt),
                        style: DriverText.body.copyWith(
                          color: DriverColors.text,
                        ),
                      ),
                    ),
                    Text(formatRubles(t.fullPrice), style: DriverText.title),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(
      color: DriverColors.text,
      fontSize: 15,
      height: 1.33,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: DriverColors.text,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                from,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.5),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 1,
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  color: DriverColors.secondaryText,
                ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: DriverColors.text, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                to,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DriverColors.secondaryText),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: DriverColors.text,
            fontSize: 15,
            height: 1.33,
          ),
        ),
      ],
    );
  }
}

class _Requests extends StatelessWidget {
  const _Requests({required this.count, required this.avatars});

  final int count;
  final List<String> avatars;

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(2).toList();
    final extra = count - shown.length;
    Widget circle(Widget child, double left) => Positioned(
      left: left,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: DriverColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
    );
    final slots = shown.length + (extra > 0 ? 1 : 0);
    return Row(
      key: const ValueKey('trip-requests'),
      children: [
        if (slots > 0)
          SizedBox(
            width: 28 + (slots - 1) * 20.0,
            height: 28,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  circle(
                    Image.network(
                      shown[i],
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: DriverColors.secondaryText,
                      ),
                    ),
                    i * 20.0,
                  ),
                if (extra > 0)
                  circle(
                    Text(
                      '+$extra',
                      style: const TextStyle(
                        color: DriverColors.text,
                        fontSize: 12,
                      ),
                    ),
                    shown.length * 20.0,
                  ),
              ],
            ),
          ),
        const SizedBox(width: 4),
        Text(
          requestsLabel(count),
          style: const TextStyle(
            color: DriverColors.text,
            fontSize: 15,
            height: 1.33,
          ),
        ),
      ],
    );
  }
}

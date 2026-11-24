import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_trip.dart';
import '../widgets/driver_style.dart';

/// "Заказ опубликован!" with the publishing limits of the trip's day/week.
class TripPublishedPage extends StatefulWidget {
  const TripPublishedPage({
    super.key,
    required this.trip,
    required this.loadLimits,
    required this.onMyTrips,
    this.onCreateReverse,
    this.clock = DateTime.now,
  });

  final DriverTrip trip;
  final Future<PublishLimits> Function(DateTime day) loadLimits;
  final VoidCallback onMyTrips;

  /// Shown as "Создать обратную поездку" (not for a trip that is itself
  /// the way back).
  final VoidCallback? onCreateReverse;
  final DateTime Function() clock;

  @override
  State<TripPublishedPage> createState() => _TripPublishedPageState();
}

class _TripPublishedPageState extends State<TripPublishedPage> {
  late final Future<PublishLimits> _limits = widget.loadLimits(
    widget.trip.departureAt,
  );

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
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SuccessIcon(),
                        const SizedBox(height: 16),
                        const Text(
                          'Заказ опубликован!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: DriverColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Пассажиры уже видят ваш заказ. Ждём отклик!',
                            textAlign: TextAlign.center,
                            style: DriverText.body,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FutureBuilder<PublishLimits>(
                          future: _limits,
                          builder: (context, snapshot) {
                            final limits = snapshot.data;
                            if (limits == null) return const SizedBox.shrink();
                            return _LimitsCard(
                              limits: limits,
                              today: widget.clock(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('published-my-trips'),
                        onPressed: widget.onMyTrips,
                        style: FilledButton.styleFrom(
                          backgroundColor: DriverColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: DriverText.label,
                        ),
                        child: const Text('Мои заказы'),
                      ),
                    ),
                    if (widget.onCreateReverse != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const ValueKey('published-reverse'),
                          onPressed: widget.onCreateReverse,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DriverColors.primary,
                            side: const BorderSide(color: DriverColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: DriverText.label,
                          ),
                          child: const Text('Создать обратную поездку'),
                        ),
                      ),
                    ],
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

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Color(0xFFD7F2DF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: DriverColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _LimitsCard extends StatelessWidget {
  const _LimitsCard({required this.limits, required this.today});

  final PublishLimits limits;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final d = limits.date;
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final dayLabel = isToday
        ? 'Сегодня'
        : '${d.day.toString().padLeft(2, '0')}.'
              '${d.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Лимит публикаций',
            style: TextStyle(
              color: DriverColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.33,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Meter(
                  key: const ValueKey('limit-day'),
                  label: dayLabel,
                  used: limits.dayUsed,
                  limit: limits.dayLimit,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Meter(
                  key: const ValueKey('limit-week'),
                  label: 'На неделе',
                  used: limits.weekUsed,
                  limit: limits.weekLimit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final share = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: DriverText.body)),
            Text(
              '$used / $limit',
              style: DriverText.body.copyWith(color: DriverColors.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: DriverColors.background),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: share,
                  child: const ColoredBox(color: DriverColors.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

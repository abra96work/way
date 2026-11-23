import 'package:flutter/material.dart';

import '../../domain/driver_api_exception.dart';
import '../../domain/driver_trip.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';
import '../widgets/price_summary.dart';
import 'daily_limit_dialog.dart';
import 'publish_confirm_sheet.dart';
import 'route_step_page.dart';

/// "Обратное направление": the published trip mirrored, only the time is new.
/// Everything else (prices, car, extras, booking mode) is copied by the
/// backend (`POST /trips/{id}/reverse`).
class ReverseTripPage extends StatefulWidget {
  const ReverseTripPage({
    super.key,
    required this.source,
    required this.onSubmit,
    this.onBack,
    this.clock = DateTime.now,
  });

  final DriverTrip source;

  /// Creates the way back; throws [DriverApiException] on failure.
  final Future<void> Function(
    DateTime departure,
    DateTime? arrival, {
    required bool publish,
  })
  onSubmit;
  final VoidCallback? onBack;
  final DateTime Function() clock;

  @override
  State<ReverseTripPage> createState() => _ReverseTripPageState();
}

class _ReverseTripPageState extends State<ReverseTripPage> {
  DateTime? _date;
  TimeOfDay? _time;
  TimeOfDay? _arrival;
  bool _busy = false;

  DateTime? get _departureAt {
    final d = _date, t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  /// An earlier clock time than departure means the next day.
  DateTime? get _arrivalAt {
    final departure = _departureAt, t = _arrival;
    if (departure == null || t == null) return null;
    var arrival = DateTime(
      departure.year,
      departure.month,
      departure.day,
      t.hour,
      t.minute,
    );
    if (!arrival.isAfter(departure)) {
      arrival = arrival.add(const Duration(days: 1));
    }
    return arrival;
  }

  bool get _inPast {
    final departure = _departureAt;
    return departure != null && !departure.isAfter(widget.clock());
  }

  bool get _ready => _departureAt != null && !_inPast;

  Future<void> _publish() async {
    final departure = _departureAt!;
    final ok = await showPublishConfirmSheet(
      context,
      TripPreview.reverseOf(widget.source, departure),
    );
    if (ok) await _submit(publish: true);
  }

  Future<void> _submit({required bool publish}) async {
    setState(() => _busy = true);
    DailyTripLimit? limit;
    try {
      await widget.onSubmit(_departureAt!, _arrivalAt, publish: publish);
    } on DriverApiException catch (e) {
      limit = publish ? DailyTripLimit.from(e) : null;
      if (limit == null) _showError(e.message);
    } catch (_) {
      _showError(
        'Не удалось сохранить поездку. Проверьте интернет и повторите.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (limit != null && mounted) {
      final save = await showDailyLimitDialog(
        context,
        limit: limit,
        vehicleType: widget.source.vehicleType,
        today: widget.clock(),
      );
      if (save && mounted) await _submit(publish: false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: DriverColors.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DriverCalendarSheet(
        firstDay: today,
        lastDay: today.add(const Duration(days: RouteStepPage.daysAhead)),
        selected: _date,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: DriverColors.background,
      showDragHandle: true,
      builder: (_) =>
          DriverTimeSheet(initial: _time ?? nextHalfHour(widget.clock())),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickArrival() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: DriverColors.background,
      showDragHandle: true,
      builder: (_) => DriverTimeSheet(
        initial: _arrival ?? _time ?? nextHalfHour(widget.clock()),
        allowClear: _arrival != null,
      ),
    );
    if (picked == null) return;
    setState(
      () => _arrival = picked == DriverTimeSheet.cleared ? null : picked,
    );
  }

  String? _arrivalLabel() {
    final label = formatTime(_arrival);
    final arrival = _arrivalAt, departure = _departureAt;
    if (label != null &&
        arrival != null &&
        departure != null &&
        arrival.day != departure.day) {
      return '$label, на следующий день';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.source.reversedStops;
    final last = stops.length - 1;
    return NewTripScaffold(
      step: null,
      title: 'Обратное направление',
      onBack: widget.onBack,
      nextLabel: 'Опубликовать поездку',
      outlinedWhenDisabled: true,
      isSubmitting: _busy,
      onNext: _ready ? _publish : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PriceSummary(driverPrice: widget.source.fullPrice),
          const SizedBox(height: 20),
          const Text('Маршрут', style: DriverText.label),
          const SizedBox(height: 12),
          DriverCard(
            child: Column(
              children: [
                for (var i = 0; i <= last; i++)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 10,
                          child: RouteMarker(
                            kind: i == 0
                                ? MarkerKind.start
                                : i == last
                                ? MarkerKind.end
                                : MarkerKind.stop,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: _ReadOnlyStop(
                            key: ValueKey('reverse-stop-$i'),
                            label: i == last
                                ? 'Пункт назначения'
                                : 'Точка посадки',
                            text: stops[i],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Дата и время выезда', style: DriverText.label),
          const SizedBox(height: 12),
          DriverCard(
            child: Row(
              children: [
                Expanded(
                  child: DriverPickerField(
                    key: const ValueKey('reverse-date'),
                    label: 'Дата',
                    value: _date == null ? null : formatDate(_date!),
                    icon: Icons.calendar_month_rounded,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DriverPickerField(
                    key: const ValueKey('reverse-time'),
                    label: 'Время',
                    value: formatTime(_time),
                    icon: Icons.watch_later_rounded,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ),
          if (_inPast)
            const DriverHint(
              'Это время уже прошло — выберите другое',
              key: ValueKey('reverse-past-error'),
            ),
          const SizedBox(height: 20),
          const Text('Примерное время прибытия', style: DriverText.label),
          const SizedBox(height: 12),
          DriverCard(
            child: DriverPickerField(
              key: const ValueKey('reverse-arrival'),
              label: 'Время',
              value: _arrivalLabel(),
              icon: Icons.watch_later_rounded,
              onTap: _pickArrival,
            ),
          ),
        ],
      ),
    );
  }
}

/// A route point as in step 2, but not editable: the way back mirrors the
/// published route.
class _ReadOnlyStop extends StatelessWidget {
  const _ReadOnlyStop({super.key, required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DriverColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: DriverText.body.copyWith(fontSize: 12)),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DriverText.body.copyWith(color: DriverColors.text),
          ),
        ],
      ),
    );
  }
}

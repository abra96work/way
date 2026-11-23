import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';

const _errorColor = Color(0xFFD92D20);

/// "Новый заказ", step 2 of 4: route, departure date and time, approximate
/// arrival and the number of seats. Edits [draft] in place.
class RouteStepPage extends StatefulWidget {
  const RouteStepPage({
    super.key,
    required this.draft,
    required this.loadCities,
    required this.onNext,
    this.onBack,
    this.clock = DateTime.now,
  });

  final TripDraft draft;
  final Future<List<City>> Function() loadCities;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  /// Injectable "now" for tests.
  final DateTime Function() clock;

  /// The calendar offers today and the next [daysAhead] days.
  static const daysAhead = TripDraft.maxDaysAhead;

  @override
  State<RouteStepPage> createState() => _RouteStepPageState();
}

class _RouteStepPageState extends State<RouteStepPage> {
  List<City> _cities = const [];
  bool _citiesFailed = false;

  TripDraft get draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await widget.loadCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _citiesFailed = false;
      });
      // Text typed before the list arrived gets its city now.
      for (var i = 0; i < draft.stops.length; i++) {
        final stop = draft.stops[i];
        draft.updateStop(
          i,
          text: stop.text,
          city: detectCity(stop.text, cities),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _citiesFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final now = widget.clock();
        final departure = draft.departureAt;
        final departureInPast = departure != null && !departure.isAfter(now);
        final departureTooFar =
            departure != null && TripDraft.isTooFar(departure, now);
        return NewTripScaffold(
          step: 2,
          onBack: widget.onBack,
          onNext: draft.isRouteStepComplete(now) ? widget.onNext : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Маршрут', style: DriverText.label),
              const SizedBox(height: 12),
              _RouteCard(draft: draft, cities: _cities),
              if (_citiesFailed)
                DriverHint(
                  'Не удалось загрузить список городов.',
                  action: TextButton(
                    onPressed: _loadCities,
                    child: const Text('Повторить'),
                  ),
                ),
              if (draft.sameOriginAndDestination)
                const DriverHint(
                  'Пункты посадки и назначения должны быть в разных городах',
                  key: ValueKey('route-same-city-error'),
                ),
              const SizedBox(height: 20),
              const Text('Дата и время выезда', style: DriverText.label),
              const SizedBox(height: 12),
              DriverCard(
                child: Row(
                  children: [
                    Expanded(
                      child: DriverPickerField(
                        key: const ValueKey('route-date'),
                        label: 'Дата',
                        value: draft.departureDate == null
                            ? null
                            : formatDate(draft.departureDate!),
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DriverPickerField(
                        key: const ValueKey('route-time'),
                        label: 'Время',
                        value: formatTime(draft.departureTime),
                        icon: Icons.watch_later_rounded,
                        onTap: _pickDepartureTime,
                      ),
                    ),
                  ],
                ),
              ),
              if (departureInPast)
                const DriverHint(
                  'Это время уже прошло — выберите другое',
                  key: ValueKey('route-past-error'),
                ),
              if (departureTooFar)
                const DriverHint(
                  'Публиковать можно не дальше чем на 3 дня вперёд — '
                  'выберите время пораньше',
                  key: ValueKey('route-too-far-error'),
                ),
              const SizedBox(height: 20),
              const Text('Примерное время прибытия', style: DriverText.label),
              const SizedBox(height: 12),
              DriverCard(
                child: DriverPickerField(
                  key: const ValueKey('route-arrival'),
                  label: 'Время',
                  value: _arrivalLabel(),
                  icon: Icons.watch_later_rounded,
                  onTap: _pickArrivalTime,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Пассажиры', style: DriverText.label),
              const SizedBox(height: 12),
              DriverCard(child: _SeatsStepper(draft: draft)),
            ],
          ),
        );
      },
    );
  }

  String? _arrivalLabel() {
    final label = formatTime(draft.arrivalTime);
    final arrival = draft.arrivalAt;
    final departure = draft.departureAt;
    if (label == null) return null;
    if (arrival != null && departure != null && arrival.day != departure.day) {
      return '$label, на следующий день';
    }
    return label;
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
        selected: draft.departureDate,
      ),
    );
    if (picked != null) draft.departureDate = picked;
  }

  Future<void> _pickDepartureTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: DriverColors.background,
      showDragHandle: true,
      builder: (_) => DriverTimeSheet(
        initial: draft.departureTime ?? nextHalfHour(widget.clock()),
      ),
    );
    if (picked != null) draft.departureTime = picked;
  }

  Future<void> _pickArrivalTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: DriverColors.background,
      showDragHandle: true,
      builder: (_) => DriverTimeSheet(
        initial:
            draft.arrivalTime ??
            draft.departureTime ??
            nextHalfHour(widget.clock()),
        allowClear: draft.arrivalTime != null,
      ),
    );
    if (picked == DriverTimeSheet.cleared) {
      draft.arrivalTime = null;
    } else if (picked != null) {
      draft.arrivalTime = picked;
    }
  }
}

/// The next :00 or :30 after [now] — the first time a trip can start.
TimeOfDay nextHalfHour(DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  final next = ((minutes ~/ 30) + 1) * 30 % (24 * 60);
  return TimeOfDay(hour: next ~/ 60, minute: next % 60);
}

// ---------- formatting ----------

/// "04.06.2026"
String formatDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.'
    '${day.month.toString().padLeft(2, '0')}.${day.year}';

/// "8:00"
String? formatTime(TimeOfDay? time) => time == null
    ? null
    : '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

const _monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

// ---------- route ----------

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.draft, required this.cities});

  final TripDraft draft;
  final List<City> cities;

  @override
  Widget build(BuildContext context) {
    final stops = draft.stops;
    final last = stops.length - 1;
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i <= last; i++)
            IntrinsicHeight(
              key: ValueKey('route-row-${stops[i].id}'),
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
                    child: _StopField(
                      // Keyed by the stop, not the index: state survives removals.
                      key: ValueKey('route-point-${stops[i].id}'),
                      stop: stops[i],
                      label: i == last ? 'Пункт назначения' : 'Точка посадки',
                      cities: cities,
                      removable: i != 0 && i != last,
                      onChanged: (text, city) =>
                          draft.updateStop(i, text: text, city: city),
                      onRemove: () => draft.removeStop(i),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 11),
          if (draft.canAddStop)
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                key: const ValueKey('route-add-stop'),
                onPressed: draft.addStop,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Добавить остановку'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DriverColors.primary,
                  side: const BorderSide(color: DriverColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.33,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline address input with city suggestions after the last comma.
class _StopField extends StatefulWidget {
  const _StopField({
    super.key,
    required this.stop,
    required this.label,
    required this.cities,
    required this.removable,
    required this.onChanged,
    required this.onRemove,
  });

  final RouteStop stop;
  final String label;
  final List<City> cities;
  final bool removable;
  final void Function(String text, City? city) onChanged;
  final VoidCallback onRemove;

  @override
  State<_StopField> createState() => _StopFieldState();
}

class _StopFieldState extends State<_StopField> {
  late final _controller = TextEditingController(text: widget.stop.text);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_StopField old) {
    super.didUpdateWidget(old);
    if (widget.stop.text != _controller.text) {
      _controller.text = widget.stop.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String text) =>
      widget.onChanged(text, detectCity(text, widget.cities));

  /// Text after the last comma (or all of it): what the driver is typing now.
  String _fragment(String text) {
    final comma = text.lastIndexOf(',');
    return (comma < 0 ? text : text.substring(comma + 1)).trim();
  }

  Iterable<City> _suggestions(TextEditingValue value) {
    final fragment = foldName(_fragment(value.text));
    if (fragment.length < 2) return const [];
    final matches =
        widget.cities.where((c) => foldName(c.name).contains(fragment)).toList()
          ..sort(
            (a, b) => (foldName(a.name).startsWith(fragment) ? 0 : 1).compareTo(
              foldName(b.name).startsWith(fragment) ? 0 : 1,
            ),
          );
    // Nothing to suggest once the typed fragment already is a city.
    if (matches.length == 1 && foldName(matches.first.name) == fragment) {
      return const [];
    }
    return matches.take(5);
  }

  /// Address with the typed city fragment replaced by [city]'s name.
  /// RawAutocomplete writes this into the field when a suggestion is picked.
  String _withCity(City city) {
    final text = _controller.text;
    final comma = text.lastIndexOf(',');
    final street = comma < 0 ? '' : text.substring(0, comma).trim();
    return street.isEmpty ? city.name : '$street, ${city.name}';
  }

  void _select(City city) => widget.onChanged(_controller.text, city);

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final missingCity = !_focus.hasFocus && !stop.isEmpty && stop.city == null;
    final showClear = widget.removable || _controller.text.isNotEmpty;
    return RawAutocomplete<City>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: _suggestions,
      displayStringForOption: _withCity,
      onSelected: _select,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: _changed,
        textCapitalization: TextCapitalization.sentences,
        style: DriverText.body.copyWith(color: DriverColors.text),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: DriverText.body,
          floatingLabelStyle: DriverText.body.copyWith(fontSize: 12),
          hintText: _focus.hasFocus ? 'Улица, дом, город' : null,
          hintStyle: DriverText.body,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 10, 0, 8),
          errorText: missingCity
              ? 'Добавьте город из списка через запятую'
              : null,
          errorStyle: const TextStyle(color: _errorColor, fontSize: 12),
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: DriverColors.divider),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: DriverColors.divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: DriverColors.text),
          ),
          errorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _errorColor),
          ),
          suffixIcon: showClear
              ? IconButton(
                  key: ValueKey('route-clear-${stop.id}'),
                  tooltip: widget.removable ? 'Убрать остановку' : 'Очистить',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: DriverColors.text,
                  ),
                  onPressed: () {
                    if (widget.removable) {
                      widget.onRemove();
                    } else {
                      controller.clear();
                      widget.onChanged('', null);
                    }
                  },
                )
              : null,
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          color: DriverColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 300),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              children: [
                for (final city in options)
                  ListTile(
                    key: ValueKey('route-suggestion-${city.id}'),
                    dense: true,
                    title: Text(city.name, style: DriverText.label),
                    subtitle: city.region.isEmpty
                        ? null
                        : Text(city.region, style: DriverText.body),
                    onTap: () => onSelected(city),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum MarkerKind { start, stop, end }

/// Filled square at the start, dots for stops, outlined square at the end,
/// dashed line between them.
class RouteMarker extends StatelessWidget {
  const RouteMarker({super.key, required this.kind});

  final MarkerKind kind;

  @override
  Widget build(BuildContext context) {
    final marker = switch (kind) {
      MarkerKind.start => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: DriverColors.text,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      MarkerKind.stop => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: DriverColors.text,
          shape: BoxShape.circle,
        ),
      ),
      MarkerKind.end => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(color: DriverColors.text, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    };
    return CustomPaint(
      painter: _DashPainter(
        top: kind != MarkerKind.start,
        bottom: kind != MarkerKind.end,
      ),
      child: Align(alignment: const Alignment(0, 0.2), child: marker),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.top, required this.bottom});

  final bool top;
  final bool bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DriverColors.text
      ..strokeWidth = 1;
    final x = size.width / 2;
    final mid = size.height * 0.6;
    void dashed(double from, double to) {
      for (var y = from; y < to; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + 3).clamp(from, to)),
          paint,
        );
      }
    }

    if (top) dashed(0, mid - 6);
    if (bottom) dashed(mid + 6, size.height);
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.top != top || old.bottom != bottom;
}

// ---------- fields ----------

class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DriverColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class DriverHint extends StatelessWidget {
  const DriverHint(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _errorColor, fontSize: 13),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Read-only 52 px field with a floating label: "Дата" over "04.06.2026".
class DriverPickerField extends StatelessWidget {
  const DriverPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Semantics(
      button: true,
      label: hasValue ? '$label: $value' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DriverColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: hasValue
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: DriverText.body.copyWith(fontSize: 12),
                          ),
                          Text(
                            value!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DriverText.body.copyWith(
                              color: DriverColors.text,
                            ),
                          ),
                        ],
                      )
                    : Text(label, style: DriverText.body),
              ),
              Icon(icon, size: 18, color: DriverColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatsStepper extends StatelessWidget {
  const _SeatsStepper({required this.draft});

  final TripDraft draft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Количество мест:',
              style: DriverText.body.copyWith(color: DriverColors.text),
            ),
          ),
          _StepperButton(
            key: const ValueKey('route-seats-minus'),
            icon: Icons.remove_circle,
            tooltip: 'Меньше мест',
            onPressed: draft.seats > 0
                ? () => draft.seats = draft.seats - 1
                : null,
          ),
          SizedBox(
            width: 92,
            child: Text(
              '${draft.seats}',
              key: const ValueKey('route-seats-value'),
              textAlign: TextAlign.center,
              style: DriverText.body.copyWith(color: DriverColors.text),
            ),
          ),
          _StepperButton(
            key: const ValueKey('route-seats-plus'),
            icon: Icons.add_circle,
            tooltip: 'Больше мест',
            onPressed: draft.seats < draft.vehicleType.maxSeats
                ? () => draft.seats = draft.seats + 1
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: DriverColors.divider),
          ),
        ),
        icon: Icon(
          icon,
          size: 24,
          color: onPressed == null ? DriverColors.divider : DriverColors.text,
        ),
      ),
    );
  }
}

// ---------- sheets ----------

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
    required this.buttonLabel,
    required this.onConfirm,
    this.extra,
  });

  final String title;
  final Widget child;
  final String buttonLabel;
  final VoidCallback? onConfirm;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: DriverText.label),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DriverColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            ),
            const SizedBox(height: 16),
            ?extra,
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('sheet-confirm'),
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: DriverColors.primary,
                  disabledBackgroundColor: DriverColors.divider,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Выбрать дату": a month grid; only [firstDay]..[lastDay] can be picked.
class DriverCalendarSheet extends StatefulWidget {
  const DriverCalendarSheet({
    super.key,
    required this.firstDay,
    required this.lastDay,
    this.selected,
  });

  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime? selected;

  @override
  State<DriverCalendarSheet> createState() => _DriverCalendarSheetState();
}

class _DriverCalendarSheetState extends State<DriverCalendarSheet> {
  late DateTime? _selected = widget.selected;
  late DateTime _month = DateTime(
    (widget.selected ?? widget.firstDay).year,
    (widget.selected ?? widget.firstDay).month,
  );

  bool _enabled(DateTime day) =>
      !day.isBefore(widget.firstDay) && !day.isAfter(widget.lastDay);

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month).weekday - 1; // Mon=0
    final canPrev = DateTime(
      _month.year,
      _month.month,
    ).isAfter(DateTime(widget.firstDay.year, widget.firstDay.month));
    final canNext = DateTime(
      _month.year,
      _month.month + 1,
    ).isBefore(DateTime(widget.lastDay.year, widget.lastDay.month + 1));
    return _SheetFrame(
      title: 'Выбрать дату',
      buttonLabel: 'Выбрать дату',
      onConfirm: _selected == null
          ? null
          : () => Navigator.of(context).pop(_selected),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  key: const ValueKey('calendar-month'),
                  style: DriverText.cardTitle,
                ),
              ),
              IconButton(
                tooltip: 'Предыдущий месяц',
                onPressed: canPrev
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                key: const ValueKey('calendar-next'),
                tooltip: 'Следующий месяц',
                onPressed: canNext
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in const ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: DriverText.body.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _DayCell(
                  day: DateTime(_month.year, _month.month, d),
                  enabled: _enabled(DateTime(_month.year, _month.month, d)),
                  selected:
                      _selected != null &&
                      _selected!.year == _month.year &&
                      _selected!.month == _month.month &&
                      _selected!.day == d,
                  onTap: (day) => setState(() => _selected = day),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool enabled;
  final bool selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkResponse(
        key: ValueKey('calendar-day-${day.month}-${day.day}'),
        onTap: enabled ? () => onTap(day) : null,
        radius: 20,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: selected
              ? const BoxDecoration(
                  color: DriverColors.primary,
                  shape: BoxShape.circle,
                )
              : null,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : enabled
                  ? DriverColors.text
                  : DriverColors.secondaryText.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Выбрать время": hour and minute wheels, minutes in 30-minute steps.
class DriverTimeSheet extends StatefulWidget {
  const DriverTimeSheet({
    super.key,
    required this.initial,
    this.allowClear = false,
  });

  final TimeOfDay initial;
  final bool allowClear;

  /// Returned when the driver removes an optional time.
  static const cleared = TimeOfDay(hour: 0, minute: 1);

  @override
  State<DriverTimeSheet> createState() => _DriverTimeSheetState();
}

class _DriverTimeSheetState extends State<DriverTimeSheet> {
  static const _minutes = [0, 30];

  late int _hour = widget.initial.hour;
  late int _minuteIndex = widget.initial.minute >= 30 ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    Widget wheel({
      required Key key,
      required int count,
      required int initial,
      required ValueChanged<int> onChanged,
      required String Function(int) label,
    }) => SizedBox(
      width: 80,
      child: CupertinoPicker(
        key: key,
        itemExtent: 36,
        scrollController: FixedExtentScrollController(initialItem: initial),
        selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
          background: Color(0x14000000),
        ),
        onSelectedItemChanged: onChanged,
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                label(i),
                style: const TextStyle(fontSize: 20, color: DriverColors.text),
              ),
            ),
        ],
      ),
    );

    return _SheetFrame(
      title: 'Выбрать время',
      buttonLabel: 'Выбрать время',
      onConfirm: () =>
          Navigator.of(context)
              .pop(TimeOfDay(hour: _hour, minute: _minutes[_minuteIndex])),
      extra: widget.allowClear
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                key: const ValueKey('time-clear'),
                onPressed: () =>
                    Navigator.of(context).pop(DriverTimeSheet.cleared),
                child: const Text('Не указывать'),
              ),
            )
          : null,
      child: SizedBox(
        height: 180,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            wheel(
              key: const ValueKey('time-hours'),
              count: 24,
              initial: _hour,
              onChanged: (i) => _hour = i,
              label: (i) => '$i',
            ),
            wheel(
              key: const ValueKey('time-minutes'),
              count: _minutes.length,
              initial: _minuteIndex,
              onChanged: (i) => _minuteIndex = i,
              label: (i) => _minutes[i].toString().padLeft(2, '0'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/driver_api_exception.dart';
import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';

/// "Достигнут лимит на сегодня": shown when `POST /trips` answers
/// `daily_trip_limit`. Pops `true` for "Сохранить как шаблон".
Future<bool> showDailyLimitDialog(
  BuildContext context, {
  required DailyTripLimit limit,
  required VehicleType vehicleType,
  required DateTime today,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x660C0C0C),
    builder: (_) =>
        DailyLimitDialog(limit: limit, vehicleType: vehicleType, today: today),
  );
  return result ?? false;
}

class DailyLimitDialog extends StatelessWidget {
  const DailyLimitDialog({
    super.key,
    required this.limit,
    required this.vehicleType,
    required this.today,
  });

  final DailyTripLimit limit;
  final VehicleType vehicleType;
  final DateTime today;

  bool get _isToday {
    final d = limit.date;
    return d == null ||
        (d.year == today.year && d.month == today.month && d.day == today.day);
  }

  String get _day {
    final d = limit.date!;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = vehicleType == VehicleType.bus
        ? 'автобус'
        : 'легковой автомобиль';
    final when = _isToday ? 'Сегодня' : 'На $_day';
    final text =
        'На $vehicle можно опубликовать не более 1 поездки в сутки '
        'в двух направлениях (туда и обратно). '
        '$when у вас уже ${limit.published} ${publicationsWord(limit.published)}.';

    return Dialog(
      backgroundColor: DriverColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset(
                'assets/images/driver/daily_limit.png',
                width: 79,
                height: 70,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 79,
                  height: 70,
                  child: Icon(
                    Icons.event_busy_outlined,
                    size: 56,
                    color: DriverColors.secondaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isToday
                  ? 'Достигнут лимит на сегодня'
                  : 'Достигнут лимит на этот день',
              textAlign: TextAlign.center,
              style: DriverText.title,
            ),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: DriverText.body),
            const SizedBox(height: 16),
            _Counter(
              key: const ValueKey('limit-there'),
              label: 'Туда',
              used: limit.thereUsed,
              limit: limit.thereLimit,
            ),
            const SizedBox(height: 20),
            _Counter(
              key: const ValueKey('limit-back'),
              label: 'Обратно',
              used: limit.backUsed,
              limit: limit.backLimit,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: FilledButton(
                key: const ValueKey('limit-save-template'),
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: DriverColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: _buttonText,
                ),
                child: const Text('Сохранить как шаблон'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                key: const ValueKey('limit-cancel'),
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DriverColors.primary,
                  side: const BorderSide(color: DriverColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: _buttonText,
                ),
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _buttonText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.38,
  );
}

/// "1 публикация", "2 публикации", "5 публикаций" (word only).
String publicationsWord(int n) {
  if (n % 10 == 1 && n % 100 != 11) return 'публикация';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)) {
    return 'публикации';
  }
  return 'публикаций';
}

class _Counter extends StatelessWidget {
  const _Counter({
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
              '$used/$limit',
              style: DriverText.body.copyWith(color: DriverColors.text),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 7,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: DriverColors.surface),
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

import 'package:flutter/material.dart';

import '../../domain/pricing.dart';
import 'driver_style.dart';

/// "Общая стоимость / Комиссия / Вы получите" for the whole route.
class PriceSummary extends StatelessWidget {
  const PriceSummary({super.key, required this.driverPrice});

  final int driverPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                key: const ValueKey('price-total'),
                label: 'Общая стоимость',
                value: passengerPriceFor(driverPrice),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                key: const ValueKey('price-commission'),
                label: 'Комиссия',
                value: commissionFor(driverPrice),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('price-driver-gets'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: _tileDecoration,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Вы получите',
                  style: DriverText.body.copyWith(color: DriverColors.text),
                ),
              ),
              Text(formatRubles(driverPrice), style: DriverText.cardTitle),
            ],
          ),
        ),
      ],
    );
  }
}

final _tileDecoration = BoxDecoration(
  color: DriverColors.surface,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: DriverColors.divider),
);

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({super.key, required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _tileDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DriverText.body.copyWith(
              fontSize: 13,
              color: DriverColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(formatRubles(value), style: DriverText.label),
        ],
      ),
    );
  }
}

/// "1 250 ₽"
String formatRubles(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer ₽';
}

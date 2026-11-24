import 'package:flutter/material.dart';

import '../../domain/driver_trip.dart';
import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/price_summary.dart';
import 'route_step_page.dart' show formatDate;

/// "Опубликовать поездку?" — the last look before publishing.
/// Resolves to `true` on "Да, опубликовать".
Future<bool> showPublishConfirmSheet(
  BuildContext context,
  TripPreview preview,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DriverColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => PublishConfirmSheet(preview: preview),
  );
  return result ?? false;
}

class PublishConfirmSheet extends StatefulWidget {
  const PublishConfirmSheet({super.key, required this.preview});

  final TripPreview preview;

  @override
  State<PublishConfirmSheet> createState() => _PublishConfirmSheetState();
}

class _PublishConfirmSheetState extends State<PublishConfirmSheet> {
  bool _showSegments = false;

  TripPreview get p => widget.preview;

  @override
  Widget build(BuildContext context) {
    final stops = p.stops;
    final d = p.departureAt;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    final small = DriverText.body.copyWith(fontSize: 13, height: 1.38);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: DriverColors.divider,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Опубликовать поездку?',
                    style: DriverText.cardTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'После публикации пассажиры смогут увидеть и забронировать '
                    'места. Изменить поездку можно будет до того, как '
                    'присоединится первый пассажир.',
                    style: DriverText.body,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  color: DriverColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Row('Точка посадки', stops.first),
                      _Row('Пункт назначения', stops.last),
                      if (stops.length > 2)
                        _Row('Доп. остановки', '${stops.length - 2}'),
                      _Row('Дата и время', '${formatDate(d)}, $time'),
                      _Row(
                        'Стоимость поездки',
                        formatRubles(p.fullPrice),
                        bold: true,
                      ),
                      if (p.segmentPrices.isNotEmpty) ...[
                        _Row(
                          'Между остановками',
                          null,
                          trailing: _ToggleChip(
                            open: _showSegments,
                            onTap: () =>
                                setState(() => _showSegments = !_showSegments),
                          ),
                        ),
                        if (_showSegments)
                          for (var i = 0; i < p.segmentPrices.length; i++)
                            _Row(
                              '${stops[i]} –\n${stops[i + 1]}',
                              formatRubles(p.segmentPrices[i]),
                              labelStyle: small,
                              key: ValueKey('confirm-segment-$i'),
                            ),
                      ],
                      if (p.extras.isNotEmpty)
                        _Row('Цена доп. услуг', formatRubles(p.extrasPrice)),
                      _Row('Автомобиль', p.carTitle),
                      _Row(
                        'Доп. услуги',
                        p.extras.isEmpty
                            ? 'Нет'
                            : [
                                for (final k in TripExtraKind.values)
                                  if (p.extras.containsKey(k)) k.title,
                              ].join(', '),
                      ),
                      if (p.parcelSizes.isNotEmpty)
                        _Row(
                          'Посылки',
                          p.parcelSizes.map((s) => s.title).join(', '),
                        ),
                      _Row(
                        'Тип бронирования',
                        p.bookingMode == BookingMode.instant
                            ? 'Быстрое'
                            : 'Стандартное',
                        divider: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const ValueKey('confirm-cancel'),
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DriverColors.primary,
                          side: const BorderSide(color: DriverColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: DriverText.label,
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('confirm-publish'),
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: DriverColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: DriverText.label,
                        ),
                        child: const Text('Да, опубликовать'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
    this.trailing,
    this.labelStyle,
    this.divider = true,
  });

  final String label;
  final String? value;
  final bool bold;
  final Widget? trailing;
  final TextStyle? labelStyle;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: DriverColors.divider)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: labelStyle ?? DriverText.body),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else
            Expanded(
              flex: 5,
              child: Text(
                value ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: bold ? TextAlign.right : TextAlign.left,
                style: DriverText.body.copyWith(
                  color: DriverColors.text,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        key: const ValueKey('confirm-segments-toggle'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: DriverColors.primary,
          side: const BorderSide(color: DriverColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.33,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(open ? 'Скрыть стоимость' : 'Смотреть стоимость'),
            const SizedBox(width: 2),
            Icon(
              open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

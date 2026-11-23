import 'package:flutter/material.dart';

import '../../domain/driver_api_exception.dart';
import '../../domain/driver_trip.dart';
import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/new_trip_scaffold.dart';
import 'daily_limit_dialog.dart';
import 'publish_confirm_sheet.dart';

/// "Новый заказ", step 6 of 6: booking mode, then publish or save a draft.
class BookingStepPage extends StatefulWidget {
  const BookingStepPage({
    super.key,
    required this.draft,
    required this.onPublish,
    required this.onSaveTemplate,
    this.onBack,
    this.clock = DateTime.now,
  });

  final TripDraft draft;

  /// "Today" for the daily-limit dialog; replaced in tests.
  final DateTime Function() clock;

  /// Both throw [DriverApiException] with the server's reason on failure.
  final Future<void> Function() onPublish;
  final Future<void> Function() onSaveTemplate;
  final VoidCallback? onBack;

  @override
  State<BookingStepPage> createState() => _BookingStepPageState();
}

enum _Busy { none, publish, template }

class _BookingStepPageState extends State<BookingStepPage> {
  _Busy _busy = _Busy.none;

  TripDraft get draft => widget.draft;

  Future<void> _run(_Busy kind, Future<void> Function() action) async {
    setState(() => _busy = kind);
    DailyTripLimit? limit;
    try {
      await action();
    } on DriverApiException catch (e) {
      limit = kind == _Busy.publish ? DailyTripLimit.from(e) : null;
      if (limit == null) _showError(e.message);
    } catch (_) {
      _showError(
        'Не удалось сохранить поездку. Проверьте интернет и повторите.',
      );
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
    if (limit != null && mounted) await _onDailyLimit(limit);
  }

  Future<void> _confirmAndPublish() async {
    final ok = await showPublishConfirmSheet(
      context,
      TripPreview.fromDraft(draft),
    );
    if (ok && mounted) await _run(_Busy.publish, widget.onPublish);
  }

  /// The day is full: offer to keep the trip as a template instead.
  Future<void> _onDailyLimit(DailyTripLimit limit) async {
    final save = await showDailyLimitDialog(
      context,
      limit: limit,
      vehicleType: draft.vehicleType,
      today: widget.clock(),
    );
    if (save && mounted) await _run(_Busy.template, widget.onSaveTemplate);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => NewTripScaffold(
        step: 6,
        onBack: widget.onBack,
        nextLabel: 'Опубликовать поездку',
        isSubmitting: _busy == _Busy.publish,
        onNext: draft.bookingMode == null ? null : _confirmAndPublish,
        secondaryLabel: 'Сохранить шаблон',
        isSecondarySubmitting: _busy == _Busy.template,
        onSecondary: () => _run(_Busy.template, widget.onSaveTemplate),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Тип бронирования', style: DriverText.label),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DriverColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _ModeCard(
                    key: const ValueKey('booking-manual'),
                    title: 'Стандартное',
                    subtitle: 'Вы рассматриваете каждую заявку отдельно',
                    points: const [
                      'Вы получаете уведомление о заявке',
                      'Можете перейти в профиль пассажира',
                      'Подтверждаете или отклоняете бронь',
                      'После подтверждения пассажир оплачивает',
                    ],
                    selected: draft.bookingMode == BookingMode.manual,
                    onTap: () => draft.bookingMode = BookingMode.manual,
                  ),
                  const SizedBox(height: 8),
                  _ModeCard(
                    key: const ValueKey('booking-instant'),
                    title: 'Быстрое бронирование',
                    subtitle: 'Без подтверждения каждой заявки',
                    points: const [
                      'Пассажир сразу оплачивает место',
                      'Подтверждение не требуется',
                      'Подходит для постоянных маршрутов',
                    ],
                    selected: draft.bookingMode == BookingMode.instant,
                    onTap: () => draft.bookingMode = BookingMode.instant,
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<String> points;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final small = DriverText.body.copyWith(fontSize: 13, height: 1.38);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? const Color(0xFFE6F6EB) : DriverColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? DriverColors.primary : DriverColors.divider,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: DriverText.label)),
                    const SizedBox(width: 8),
                    _Radio(selected: selected),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: small),
                const SizedBox(height: 8),
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 7, 8, 0),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: DriverColors.secondaryText,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(child: Text(point, style: small)),
                      ],
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

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DriverColors.primary, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: DriverColors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

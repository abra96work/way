import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_api_exception.dart';
import '../../domain/driver_profile.dart' show tripsLabel;
import '../../domain/driver_trip.dart';
import '../../domain/pricing.dart';
import '../../domain/trip_draft.dart';
import '../widgets/driver_style.dart';
import '../widgets/price_summary.dart' show formatRubles;
import '../widgets/success_toast.dart';

/// What cancelling would mean (`GET /trips/{id}/cancel-preview`).
class CancelPreview {
  const CancelPreview({
    required this.isViolation,
    this.warning,
    this.blocksAccount = false,
  });

  factory CancelPreview.fromJson(Map<String, dynamic> json) => CancelPreview(
    isViolation: json['is_violation'] as bool? ?? false,
    warning: json['warning'] as String?,
    blocksAccount: json['blocks_account'] as bool? ?? false,
  );

  final bool isViolation;
  final String? warning;
  final bool blocksAccount;
}

/// A trip with its bookings, loaded together.
typedef TripWithBookings = ({DriverTrip trip, List<TripBooking> bookings});

/// "Поездка": the driver's own trip — route, prices, seats, extras,
/// passengers, car — with "Редактировать" and "Отменить поездку".
/// Pops `true` when the trip was cancelled or deleted.
class DriverTripPage extends StatefulWidget {
  const DriverTripPage({
    super.key,
    required this.load,
    required this.loadCancelPreview,
    required this.cancelTrip,
    required this.deleteDraft,
    this.onEdit,
    this.changeSeats,
    this.setAcceptingBookings,
    this.onTransferPassengers,
    this.onOpenBooking,
    this.onOpenDriver,
    this.confirmBooking,
    this.rejectBooking,
    this.openBookingId,
  });

  final Future<TripWithBookings> Function() load;
  final Future<CancelPreview> Function(String tripId) loadCancelPreview;

  /// Both throw [DriverApiException] with the reason.
  final Future<void> Function(String tripId) cancelTrip;
  final Future<void> Function(String tripId) deleteDraft;
  final ValueChanged<DriverTrip>? onEdit;

  /// `PATCH /trips/{id}/seats`; throws [DriverApiException].
  final Future<void> Function(String tripId, int seats)? changeSeats;

  /// «Завершить приём пассажиров» (false) or resume it (true).
  final Future<void> Function(String tripId, bool accepting)?
  setAcceptingBookings;

  /// «Передать пассажиров» (shown while someone is in the trip).
  final ValueChanged<DriverTrip>? onTransferPassengers;

  /// Opens the passenger's profile; the trip reloads when it closes.
  final Future<void> Function(TripBooking booking)? onOpenBooking;

  /// A pending request: "Подтвердить бронь" / "Отклонить бронь".
  /// Both throw [DriverApiException] with the reason.
  final Future<void> Function(String bookingId)? confirmBooking;
  final Future<void> Function(String bookingId)? rejectBooking;

  /// Opens this request right away ("Перейти к отклику").
  final String? openBookingId;
  final VoidCallback? onOpenDriver;

  @override
  State<DriverTripPage> createState() => _DriverTripPageState();
}

class _DriverTripPageState extends State<DriverTripPage> {
  late Future<TripWithBookings> _data = widget.load();
  bool _busy = false;

  void _reload() => setState(() {
    _data = widget.load();
  });

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on DriverApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Не получилось. Проверьте интернет и повторите.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(DriverTrip trip) async {
    CancelPreview preview;
    try {
      preview = await widget.loadCancelPreview(trip.id);
    } on DriverApiException catch (e) {
      return _showError(e.message);
    } catch (_) {
      return _showError('Не удалось проверить отмену. Повторите позже.');
    }
    if (!mounted) return;
    final ok = await _confirm(
      title: 'Отменить поездку?',
      text: preview.isViolation
          ? (preview.warning ??
                'Пассажиры уже зарегистрированы — отмена нарушит правила '
                    'сообщества.')
          : 'Поездка пропадёт из поиска. Пассажиров ещё нет, нарушения не будет.',
      warning: preview.blocksAccount
          ? 'Это вторая такая отмена за 30 дней — аккаунт будет '
                'заблокирован на 30 дней.'
          : null,
      confirmLabel: 'Отменить поездку',
    );
    if (ok) await _run(() => widget.cancelTrip(trip.id));
  }

  Future<void> _delete(DriverTrip trip) async {
    final ok = await _confirm(
      title: 'Удалить шаблон?',
      text: 'Шаблон пропадёт из «Мои заказы». Это нельзя отменить.',
      confirmLabel: 'Удалить',
    );
    if (ok) await _run(() => widget.deleteDraft(trip.id));
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String confirmLabel,
    String? warning,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Text(
                warning,
                key: const ValueKey('cancel-blocks-account'),
                style: const TextStyle(color: _red),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Назад'),
          ),
          TextButton(
            key: const ValueKey('confirm-destructive'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _openRequestedBooking();
  }

  /// "Перейти к отклику": show that request once the trip has loaded.
  Future<void> _openRequestedBooking() async {
    final id = widget.openBookingId;
    if (id == null || _autoOpened) return;
    try {
      final data = await _data;
      final booking = data.bookings.where((b) => b.id == id).firstOrNull;
      if (booking == null || !mounted) return;
      _autoOpened = true;
      await _openBooking(data.trip, booking);
    } catch (_) {
      // The page shows its own load error.
    }
  }

  Future<void> _openBooking(DriverTrip trip, TripBooking booking) async {
    final canDecide =
        booking.status == TripBookingStatus.pending &&
        widget.confirmBooking != null &&
        widget.rejectBooking != null;
    if (canDecide) {
      final result = await Navigator.of(context).push<BookingDecision>(
        MaterialPageRoute(
          builder: (_) => BookingRequestPage(
            trip: trip,
            booking: booking,
            confirm: widget.confirmBooking!,
            reject: widget.rejectBooking!,
            onOpenProfile: widget.onOpenBooking == null
                ? null
                : () => widget.onOpenBooking!(booking),
          ),
        ),
      );
      if (!mounted || result == null) return;
      showSuccessToast(
        ScaffoldMessenger.of(context),
        result == BookingDecision.confirmed
            ? 'Бронь подтверждена'
            : 'Бронь отклонена',
      );
      _reload();
      return;
    }
    if (widget.onOpenBooking == null) return;
    await widget.onOpenBooking!(booking);
    if (mounted) _reload();
  }

  List<_MenuAction> _menu(DriverTrip trip, List<TripBooking> bookings) {
    final active = trip.status == TripStatus.published;
    final hasPassengers = bookings.any((b) => b.status.isActive);
    return [
      if (active && widget.changeSeats != null)
        (
          key: 'trip-seats-change',
          icon: Icons.airline_seat_recline_normal_rounded,
          label: 'Изменить количество мест',
          onTap: () => _changeSeats(trip),
        ),
      if ((active || trip.status == TripStatus.draft) && widget.onEdit != null)
        (
          key: 'trip-edit',
          icon: Icons.edit_rounded,
          label: 'Редактировать',
          onTap: () =>
              trip.isEditable ? widget.onEdit!(trip) : _explainLocked(trip),
        ),
      if (active && hasPassengers && widget.onTransferPassengers != null)
        (
          key: 'trip-transfer',
          icon: Icons.group_outlined,
          label: 'Передать пассажиров',
          onTap: () => widget.onTransferPassengers!(trip),
        ),
      if (active && widget.setAcceptingBookings != null)
        trip.acceptsBookings
            ? (
                key: 'trip-close-booking',
                icon: Icons.person_off_outlined,
                label: 'Завершить приём пассажиров',
                onTap: () => _closeBooking(trip),
              )
            : (
                key: 'trip-open-booking',
                icon: Icons.person_add_alt_outlined,
                label: 'Возобновить приём пассажиров',
                onTap: () => _toggleBooking(trip, accepting: true),
              ),
    ];
  }

  /// Passengers joined: the backend keeps route, time and prices fixed.
  Future<void> _explainLocked(DriverTrip trip) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: DriverColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _SheetFrame(
      key: const ValueKey('edit-locked'),
      title: 'Редактирование недоступно',
      children: [
        Text(
          'К поездке уже присоединились пассажиры. Маршрут, время и '
          'стоимость изменить нельзя',
          style: DriverText.body,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            key: const ValueKey('edit-locked-ok'),
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: DriverColors.primary,
              side: const BorderSide(color: DriverColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.38,
              ),
            ),
            child: const Text('Понятно'),
          ),
        ),
      ],
    ),
  );

  Future<void> _changeSeats(DriverTrip trip) async {
    final booked = trip.seatsTotal - trip.seatsAvailable;
    final seats = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: DriverColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SeatsSheet(
        initial: trip.seatsTotal,
        min: booked < 1 ? 1 : booked,
        // Never below what the trip already has (the car allowed it).
        max: trip.seatsTotal > trip.vehicleType.maxSeats
            ? trip.seatsTotal
            : trip.vehicleType.maxSeats,
        booked: booked,
      ),
    );
    if (seats == null || seats == trip.seatsTotal || !mounted) return;
    await _act(
      () => widget.changeSeats!(trip.id, seats),
      done: 'Изменения сохранены',
    );
  }

  Future<void> _closeBooking(DriverTrip trip) async {
    final ok = await _confirm(
      title: 'Завершить приём пассажиров?',
      text:
          'Поездка пропадёт из поиска, новые заявки не придут. Уже '
          'записанные пассажиры останутся. Приём можно возобновить.',
      confirmLabel: 'Завершить',
    );
    if (ok) await _toggleBooking(trip, accepting: false);
  }

  Future<void> _toggleBooking(DriverTrip trip, {required bool accepting}) =>
      _act(
        () => widget.setAcceptingBookings!(trip.id, accepting),
        done: accepting
            ? 'Приём пассажиров возобновлён'
            : 'Приём пассажиров завершён',
      );

  /// Runs an action that keeps the page open, then reloads it.
  Future<void> _act(
    Future<void> Function() action, {
    required String done,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showSuccessToast(ScaffoldMessenger.of(context), done);
      _reload();
    } on DriverApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Не получилось. Проверьте интернет и повторите.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        body: SafeArea(
          child: FutureBuilder<TripWithBookings>(
            future: _data,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final trip = data?.trip;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    actions: trip == null
                        ? const []
                        : _menu(trip, data!.bookings),
                  ),
                  Expanded(child: _body(snapshot)),
                  if (trip != null) _bottom(trip),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncSnapshot<TripWithBookings> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(color: DriverColors.primary),
      );
    }
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Не удалось загрузить поездку', style: DriverText.body),
            TextButton(onPressed: _reload, child: const Text('Повторить')),
          ],
        ),
      );
    }
    final (:trip, :bookings) = snapshot.data!;
    final active = [
      for (final b in bookings)
        if (b.status.isActive) b,
    ];
    return RefreshIndicator(
      color: DriverColors.primary,
      onRefresh: () async {
        _reload();
        await _data.catchError(
          (_) => (trip: trip, bookings: const <TripBooking>[]),
        );
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 16),
        children: [
          if (trip.status == TripStatus.published && !trip.acceptsBookings)
            Container(
              key: const ValueKey('trip-booking-closed'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Приём пассажиров завершён: поездки нет в поиске, новые '
                'заявки не приходят.',
                style: TextStyle(color: DriverColors.text, fontSize: 13),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: _PriceTiles(trip: trip),
          ),
          const _Label('Маршрут'),
          _RouteCard(trip: trip),
          const SizedBox(height: 12),
          _InfoCard(trip: trip),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _Label('Пассажиры'),
            _Card(
              child: Column(
                children: [
                  for (final b in active) ...[
                    _PassengerRow(
                      booking: b,
                      onTap: () => _openBooking(trip, b),
                    ),
                    if (b != active.last) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
          if (trip.driver != null) ...[
            const SizedBox(height: 20),
            const _Label('Водитель'),
            _DriverCard(trip: trip, onOpen: widget.onOpenDriver),
          ],
          if (trip.stops.length > 2) ...[
            const SizedBox(height: 20),
            _SegmentsCard(trip: trip),
          ],
        ],
      ),
    );
  }

  Widget _bottom(DriverTrip trip) {
    final (label, action) = switch (trip.status) {
      TripStatus.published => ('Отменить поездку', () => _cancel(trip)),
      TripStatus.draft => ('Удалить шаблон', () => _delete(trip)),
      _ => (null, null),
    };
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        height: 48,
        child: FilledButton(
          key: const ValueKey('trip-cancel'),
          onPressed: _busy ? null : action,
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            disabledBackgroundColor: _red.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: DriverText.label,
          ),
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}

const _red = Color(0xFFEB4244);

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

/// "1 остановка", "2 остановки", "5 остановок".
String stopsLabel(int n) {
  final word = n % 10 == 1 && n % 100 != 11
      ? 'остановка'
      : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
      ? 'остановки'
      : 'остановок';
  return '$n $word';
}

/// An item of the "⋯" menu.
typedef _MenuAction = ({
  String key,
  IconData icon,
  String label,
  VoidCallback onTap,
});

class _Header extends StatelessWidget {
  const _Header({this.actions = const []});

  final List<_MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    Widget round(Widget child) => Material(
      color: DriverColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text('Поездка', style: DriverText.title),
          Positioned(
            left: 8,
            child: round(
              InkWell(
                key: const ValueKey('header-back'),
                onTap: () => Navigator.maybePop(context),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: DriverColors.text,
                    semanticLabel: 'Назад',
                  ),
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Positioned(
              right: 8,
              child: PopupMenuButton<String>(
                key: const ValueKey('trip-menu'),
                tooltip: 'Действия',
                color: DriverColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (key) =>
                    actions.firstWhere((a) => a.key == key).onTap(),
                itemBuilder: (_) => [
                  for (final a in actions)
                    PopupMenuItem<String>(
                      key: ValueKey(a.key),
                      value: a.key,
                      child: Row(
                        children: [
                          Icon(a.icon, size: 18, color: DriverColors.text),
                          const SizedBox(width: 8),
                          Flexible(child: Text(a.label)),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F7F8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: DriverColors.text,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(text, style: DriverText.label),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: DriverColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

/// Bordered tile: small label over a bold value.
class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: DriverColors.surface,
      border: Border.all(color: DriverColors.divider),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DriverColors.text,
            fontSize: 13,
            height: 1.38,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: DriverText.label),
      ],
    ),
  );
}

class _RouteCard extends StatefulWidget {
  const _RouteCard({required this.trip});

  final DriverTrip trip;

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final middle = t.stops.sublist(1, t.stops.length - 1);
    const big = TextStyle(color: DriverColors.text, fontSize: 15, height: 1.33);
    const small = TextStyle(
      color: DriverColors.text,
      fontSize: 13,
      height: 1.38,
    );
    Widget dots() => Padding(
      padding: const EdgeInsets.only(left: 4.5),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 1,
              height: 3,
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              color: DriverColors.secondaryText,
            ),
        ],
      ),
    );
    Widget point(Widget marker, String text, TextStyle style) => Row(
      children: [
        SizedBox(width: 10, child: Center(child: marker)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    );
    final dot = Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: DriverColors.secondaryText,
        shape: BoxShape.circle,
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          point(
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: DriverColors.text,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            t.stops.first,
            big,
          ),
          if (middle.isNotEmpty) ...[
            dots(),
            Row(
              children: [
                SizedBox(width: 10, child: Center(child: dot)),
                const SizedBox(width: 8),
                InkWell(
                  key: const ValueKey('trip-stops-toggle'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _open = !_open),
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: DriverColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stopsLabel(middle.length),
                          style: const TextStyle(
                            color: DriverColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 12,
                          color: DriverColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_open)
              for (final stop in middle) ...[dots(), point(dot, stop, small)],
          ],
          dots(),
          point(
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: DriverColors.text, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            t.stops.last,
            big,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.trip});

  final DriverTrip trip;

  static const _extras = {
    TripExtraKind.luggage: (Icons.work_outline_rounded, 'С багажом'),
    TripExtraKind.pets: (Icons.pets_outlined, 'С животными'),
    TripExtraKind.childSeat: (
      Icons.child_friendly_outlined,
      'С детским креслом',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final d = t.departureAt;
    const text = TextStyle(
      color: DriverColors.text,
      fontSize: 15,
      height: 1.33,
    );
    const bold = TextStyle(
      color: DriverColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.33,
    );
    Widget chip(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DriverColors.secondaryText),
        const SizedBox(width: 4),
        Text(label, style: text),
      ],
    );
    Widget sep() => Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: DriverColors.secondaryText,
        shape: BoxShape.circle,
      ),
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Tile(
                  'Дата и время',
                  '${d.day} ${_months[d.month - 1]}, ${_hm(d)}',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _Tile(
                  'Мест для пассажиров',
                  // As in the design: taken of total ("10 из 24" → "10 из 20").
                  '${t.seatsTotal - t.seatsAvailable} из ${t.seatsTotal}',
                  key: const ValueKey('trip-seats'),
                ),
              ),
            ],
          ),
          if (t.arrivalAt != null) ...[
            const SizedBox(height: 12),
            chip(Icons.schedule_rounded, 'Прибытие ~${_hm(t.arrivalAt!)}'),
          ],
          if (t.extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final kind in TripExtraKind.values)
                  if (t.extras.containsKey(kind))
                    chip(_extras[kind]!.$1, _extras[kind]!.$2),
              ],
            ),
          ],
          if (t.parcelSizes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 6,
              children: [
                chip(Icons.inventory_2_outlined, 'С посылкой'),
                sep(),
                Text(t.parcelSizes.map((s) => s.value).join(', '), style: bold),
                sep(),
                Text(
                  '${t.parcelSizes.length} из ${ParcelSize.values.length}',
                  style: bold,
                ),
              ],
            ),
          ],
        ],
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
      color: DriverColors.background,
      child: Icon(Icons.person_rounded, color: DriverColors.secondaryText),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: 38,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.person, this.withTrips = false});

  final TripPerson person;
  final bool withTrips;

  @override
  Widget build(BuildContext context) {
    const grey = TextStyle(
      color: Color(0xFF61636B),
      fontSize: 15,
      height: 1.33,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
        Text(person.ratingLabel, style: grey),
        if (person.reviewsCount == 0) const Text('· нет отзывов', style: grey),
        if (withTrips)
          Text('· ${tripsLabel(person.completedTrips)}', style: grey),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.booking, this.onTap});

  final TripBooking booking;
  final VoidCallback? onTap;

  /// Shown next to the name; a paid passenger needs no label.
  static (String, Color)? statusOf(TripBookingStatus status) =>
      switch (status) {
        TripBookingStatus.pending => ('Подтвердите бронь', _red),
        TripBookingStatus.awaitingPayment => (
          'Ожидает оплаты',
          DriverColors.primary,
        ),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final status = statusOf(b.status);
    return InkWell(
      key: ValueKey('trip-booking-${b.id}'),
      onTap: onTap,
      child: Row(
        children: [
          _Avatar(url: b.passenger.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        b.passenger.shortName,
                        style: DriverText.label,
                      ),
                    ),
                    if (status != null)
                      Text(
                        status.$1,
                        key: ValueKey('trip-booking-status-${b.id}'),
                        style: TextStyle(
                          color: status.$2,
                          fontSize: 13,
                          height: 1.38,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                _Rating(person: b.passenger),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: DriverColors.text,
          ),
        ],
      ),
    );
  }
}

/// "Стоимость / Комиссия / К оплате водителю" at the top of the trip.
class _PriceTiles extends StatelessWidget {
  const _PriceTiles({required this.trip, this.driverPrice});

  final DriverTrip trip;

  /// A booking's own price; the whole route when not set.
  final int? driverPrice;

  @override
  Widget build(BuildContext context) {
    final price = driverPrice ?? trip.fullPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Tile(
                'Стоимость',
                formatRubles(passengerPriceFor(price)),
                key: const ValueKey('trip-price'),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _Tile('Комиссия', formatRubles(commissionFor(price))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DriverColors.surface,
            border: Border.all(color: DriverColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'К оплате водителю',
                  style: TextStyle(
                    color: DriverColors.text,
                    fontSize: 15,
                    height: 1.33,
                  ),
                ),
              ),
              Text(
                formatRubles(price),
                key: const ValueKey('trip-driver-gets'),
                style: DriverText.cardTitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.trip, this.onOpen});

  final DriverTrip trip;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final driver = trip.driver!;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(url: driver.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.shortName, style: DriverText.label),
                    const SizedBox(height: 2),
                    _Rating(person: driver, withTrips: true),
                  ],
                ),
              ),
              if (onOpen != null)
                InkWell(
                  key: const ValueKey('trip-driver-open'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: onOpen,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: DriverColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 18),
                  ),
                ),
            ],
          ),
          if (trip.carPhotoUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 343 / 236,
                child: Image.network(
                  trip.carPhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: DriverColors.background),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 16,
                    color: DriverColors.text,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trip.carTitle,
                    style: const TextStyle(
                      color: DriverColors.text,
                      fontSize: 15,
                      height: 1.33,
                    ),
                  ),
                ],
              ),
              if (trip.carPlate != null && trip.carPlate!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: DriverColors.text),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trip.carPlate!,
                    style: const TextStyle(
                      color: DriverColors.text,
                      fontSize: 15,
                      height: 1.33,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prices between consecutive stops, as passengers pay them.
class _SegmentsCard extends StatelessWidget {
  const _SegmentsCard({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    const text = TextStyle(
      color: DriverColors.text,
      fontSize: 15,
      height: 1.33,
    );
    const bold = TextStyle(
      color: DriverColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.33,
    );
    Widget row(String label, int driverPrice, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: text)),
          const SizedBox(width: 12),
          Text(formatRubles(passengerPriceFor(driverPrice)), style: bold),
        ],
      ),
    );
    return _Card(
      child: Column(
        children: [
          row('Стоимость поездки', t.fullPrice),
          for (var i = 0; i + 1 < t.stops.length; i++)
            if (t.segmentPrices[(i, i + 1)] != null)
              row(
                '${t.stops[i]} → ${t.stops[i + 1]}',
                t.segmentPrices[(i, i + 1)]!,
                key: ValueKey('trip-segment-$i'),
              ),
        ],
      ),
    );
  }
}

/// "Изменить количество мест": a stepper from the booked seats up to the
/// vehicle's limit. Pops with the new number.
class _SeatsSheet extends StatefulWidget {
  const _SeatsSheet({
    required this.initial,
    required this.min,
    required this.max,
    required this.booked,
  });

  final int initial;
  final int min;
  final int max;
  final int booked;

  @override
  State<_SeatsSheet> createState() => _SeatsSheetState();
}

class _SeatsSheetState extends State<_SeatsSheet> {
  late int _seats = widget.initial.clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String key, VoidCallback? onTap) => InkWell(
      key: ValueKey(key),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: DriverColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 24,
          color: onTap == null ? DriverColors.divider : DriverColors.text,
        ),
      ),
    );
    final changed = _seats != widget.initial;
    return _SheetFrame(
      title: 'Количество мест',
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: DriverColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Количество мест:',
                  style: TextStyle(color: DriverColors.text, fontSize: 15),
                ),
              ),
              step(
                Icons.remove_circle,
                'seats-minus',
                _seats > widget.min ? () => setState(() => _seats--) : null,
              ),
              SizedBox(
                width: 72,
                child: Text(
                  '$_seats',
                  key: const ValueKey('seats-value'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DriverColors.text,
                    fontSize: 15,
                  ),
                ),
              ),
              step(
                Icons.add_circle,
                'seats-plus',
                _seats < widget.max ? () => setState(() => _seats++) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            key: const ValueKey('seats-save'),
            onPressed: changed ? () => Navigator.pop(context, _seats) : null,
            style: FilledButton.styleFrom(
              backgroundColor: DriverColors.primary,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: const Color(0xFF95969C),
              side: changed
                  ? null
                  : const BorderSide(color: DriverColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: DriverText.label,
            ),
            child: const Text('Сохранить'),
          ),
        ),
      ],
    );
  }
}

/// Grey bottom sheet of the design: handle, bold title, content.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 43,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCACBCE),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: DriverText.cardTitle),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// What the driver decided on a request screen.
enum BookingDecision { confirmed, rejected }

/// "Отклик": a passenger's request — the trip, the passenger's part of the
/// route and who they are — with "Отклонить бронь" / "Подтвердить бронь".
/// Pops with the [BookingDecision].
class BookingRequestPage extends StatefulWidget {
  const BookingRequestPage({
    super.key,
    required this.trip,
    required this.booking,
    required this.confirm,
    required this.reject,
    this.onOpenProfile,
  });

  final DriverTrip trip;
  final TripBooking booking;

  /// "Профиль пассажира" (before acceptance: name and rating).
  final VoidCallback? onOpenProfile;

  /// Both throw [DriverApiException] with the reason.
  final Future<void> Function(String bookingId) confirm;
  final Future<void> Function(String bookingId) reject;

  @override
  State<BookingRequestPage> createState() => _BookingRequestPageState();
}

class _BookingRequestPageState extends State<BookingRequestPage> {
  bool _busy = false;

  Future<void> _decide(BookingDecision decision) async {
    setState(() => _busy = true);
    try {
      final action = decision == BookingDecision.confirmed
          ? widget.confirm
          : widget.reject;
      await action(widget.booking.id);
      if (mounted) Navigator.of(context).pop(decision);
    } on DriverApiException catch (e) {
      _error(e.message);
    } catch (_) {
      _error('Не получилось. Проверьте интернет и повторите.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final b = widget.booking;
    const buttonText = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.38,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Scaffold(
      backgroundColor: DriverColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                    child: _PriceTiles(trip: trip, driverPrice: b.driverPrice),
                  ),
                  const _Label('Маршрут поездки'),
                  _RouteCard(trip: trip),
                  if (b.boardAddress != null && b.alightAddress != null) ...[
                    const SizedBox(height: 20),
                    const _Label('Маршрут пассажира'),
                    PassengerRouteCard(
                      board: b.boardAddress!,
                      alight: b.alightAddress!,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoCard(trip: trip),
                  const SizedBox(height: 20),
                  const _Label('Пассажир'),
                  GestureDetector(
                    key: const ValueKey('request-passenger'),
                    onTap: widget.onOpenProfile,
                    child: _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _Avatar(url: b.passenger.avatarUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.passenger.shortName,
                                      style: DriverText.label,
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      spacing: 12,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _Rating(person: b.passenger),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              b.parcelSize == null
                                                  ? Icons.person_outline_rounded
                                                  : Icons.inventory_2_outlined,
                                              size: 14,
                                              color: DriverColors.secondaryText,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              b.what,
                                              key: const ValueKey(
                                                'request-what',
                                              ),
                                              style: const TextStyle(
                                                color: DriverColors.text,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (b.phone != null) ...[
                            const SizedBox(height: 16),
                            _Tile('Номер телефона', b.phone!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        key: const ValueKey('request-reject'),
                        onPressed: _busy
                            ? null
                            : () => _decide(BookingDecision.rejected),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DriverColors.primary,
                          side: const BorderSide(color: DriverColors.primary),
                          shape: shape,
                          textStyle: buttonText,
                        ),
                        child: const Text('Отклонить бронь'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        key: const ValueKey('request-confirm'),
                        onPressed: _busy
                            ? null
                            : () => _decide(BookingDecision.confirmed),
                        style: FilledButton.styleFrom(
                          backgroundColor: DriverColors.primary,
                          shape: shape,
                          textStyle: buttonText,
                        ),
                        child: const Text('Подтвердить бронь'),
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

/// "Маршрут пассажира": where they get on and off.
class PassengerRouteCard extends StatelessWidget {
  const PassengerRouteCard({
    super.key,
    required this.board,
    required this.alight,
  });

  final String board;
  final String alight;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, String value, Widget marker, String key) => Row(
      children: [
        SizedBox(width: 10, child: Center(child: marker)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            key: ValueKey(key),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DriverColors.text)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: DriverColors.text,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: DriverColors.text,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DriverColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          field(
            'Точка посадки',
            board,
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: DriverColors.text,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            'request-board',
          ),
          const SizedBox(height: 8),
          field(
            'Точка высадки',
            alight,
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: DriverColors.text, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            'request-alight',
          ),
        ],
      ),
    );
  }
}

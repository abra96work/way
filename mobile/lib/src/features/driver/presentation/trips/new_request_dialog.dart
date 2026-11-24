import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/driver_style.dart';

/// "Новый отклик": a passenger asked to join one of the driver's trips.
/// Resolves to `true` on "Перейти к отклику".
Future<bool> showNewRequestDialog(BuildContext context) => _show(
  context,
  const DriverEventDialog(
    key: ValueKey('new-request-dialog'),
    title: 'Новый отклик',
    text:
        'Пассажир хочет присоединиться к вашей поездке. '
        'Ожидается ваше решение.',
    action: 'Перейти к отклику',
  ),
);

/// "Пассажир оплатил поездку". Resolves to `true` on "Перейти к поездке".
Future<bool> showPaidDialog(BuildContext context) => _show(
  context,
  const DriverEventDialog(
    key: ValueKey('paid-dialog'),
    title: 'Пассажир оплатил поездку',
    text:
        'Пассажир успешно оплатил поездку. '
        'Место в вашей поездке забронировано.',
    action: 'Перейти к поездке',
  ),
);

Future<bool> _show(BuildContext context, Widget dialog) async {
  final go = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x660C0C0C),
    builder: (_) => dialog,
  );
  return go ?? false;
}

/// Grey card over the current screen: map picture, title, text, button.
class DriverEventDialog extends StatelessWidget {
  const DriverEventDialog({
    super.key,
    required this.title,
    required this.text,
    required this.action,
  });

  final String title;
  final String text;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DriverColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset(
                'assets/images/driver/new_request.png',
                width: 90,
                height: 80,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 90,
                  height: 80,
                  child: Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: Color(0xFFB9BABD),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: DriverText.title),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: DriverText.body),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: FilledButton(
                key: const ValueKey('event-dialog-open'),
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: DriverColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                  ),
                ),
                child: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Driver events the app pops up (notification `type` on the backend).
enum DriverEvent {
  /// "booking_requested": a passenger asks to join.
  request('booking_requested'),

  /// "booking_paid": a passenger paid for the booking.
  paid('booking_paid');

  const DriverEvent(this.type);

  final String type;

  static DriverEvent? parse(Object? type) =>
      values.where((e) => e.type == type).firstOrNull;
}

/// An unread driver notification (`GET /notifications`).
@immutable
class RequestNotice {
  const RequestNotice({
    required this.id,
    this.tripId,
    this.bookingId,
    this.event = DriverEvent.request,
  });

  final String id;
  final String? tripId;
  final String? bookingId;
  final DriverEvent event;
}

/// Polls for driver events (new requests, payments) and pops them up one
/// at a time.
/// The backend has no push for notifications: the client polls the list.
class RequestWatcher {
  RequestWatcher({
    required this.fetchUnread,
    required this.markRead,
    required this.present,
    this.interval = const Duration(seconds: 15),
  });

  /// Unread driver-event notifications, newest first.
  final Future<List<RequestNotice>> Function() fetchUnread;
  final Future<void> Function(String notificationId) markRead;

  /// Shows the dialog and opens the trip if the driver asks to.
  final Future<void> Function(RequestNotice notice) present;
  final Duration interval;

  Timer? _timer;
  bool _busy = false;
  final _seen = <String>{};

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => check());
    check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _seen.clear();
  }

  /// One poll; skipped while a dialog is open or a request is in flight.
  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    try {
      final notices = await fetchUnread();
      final fresh = [
        for (final n in notices)
          if (_seen.add(n.id)) n,
      ];
      if (fresh.isEmpty) return;
      // Several at once: one dialog for the newest, the rest are read too.
      for (final n in fresh) {
        await markRead(n.id);
      }
      await present(fresh.first);
    } catch (_) {
      // Offline or signed out: try again on the next tick.
    } finally {
      _busy = false;
    }
  }
}

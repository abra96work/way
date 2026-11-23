import 'package:flutter/material.dart';

import '../domain/passenger_booking.dart';

const _primary = Color(0xFF1EB74D);
const _secondary = Color(0xFF8B8D92);

Future<void> showBookingAcceptedDialog(
  BuildContext context, {
  required Future<void> Function() onPay,
  required Future<void> Function() onCancel,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.42),
  builder: (_) => _BookingDialog(
    key: const ValueKey('booking-accepted-dialog'),
    title: 'Водитель принял заявку',
    message: 'Водитель подтвердил вашу заявку на поездку. Для завершения бронирования оплатите поездку.',
    primaryText: 'Перейти к оплате',
    onPrimary: () async {
      Navigator.of(context).pop();
      await onPay();
    },
    secondaryText: 'Отказаться от заявки',
    onSecondary: () async {
      Navigator.of(context).pop();
      await onCancel();
    },
  ),
);

Future<void> showBookingCancelDialog(
  BuildContext context, {
  required Future<void> Function() onConfirm,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.42),
  builder: (_) => _BookingDialog(
    key: const ValueKey('booking-cancel-dialog'),
    title: 'Отменить бронирование?',
    message: 'Водитель уже подтвердил вашу заявку. Вы уверены, что хотите отказаться от поездки?',
    primaryText: 'Вернуться',
    onPrimary: () => Navigator.of(context).pop(),
    secondaryText: 'Отказаться от заявки',
    onSecondary: () async {
      Navigator.of(context).pop();
      await onConfirm();
    },
  ),
);

Future<void> showBookingCancellationDialog(
  BuildContext context, {
  required PassengerCancellationInfo preview,
  required Future<void> Function() onConfirm,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.42),
  builder: (_) => _CancellationDialog(preview: preview, onConfirm: onConfirm),
);

Future<void> showBookingRejectedDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _BookingDialog(
        key: const ValueKey('booking-rejected-dialog'),
        title: 'Водитель отклонил заявку',
        message: 'К сожалению, водитель отклонил вашу заявку на поездку. Вы можете выбрать другую поездку или создать собственную.',
        primaryText: 'Ок',
        onPrimary: () => Navigator.of(context).pop(),
      ),
    );

class _BookingDialog extends StatelessWidget {
  const _BookingDialog({
    super.key,
    required this.title,
    required this.message,
    required this.primaryText,
    required this.onPrimary,
    this.secondaryText,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryText;
  final VoidCallback onPrimary;
  final String? secondaryText;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LocationIllustration(),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _secondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey('booking-dialog-primary'),
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Text(primaryText),
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 6),
            OutlinedButton(
              key: const ValueKey('booking-dialog-secondary'),
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(secondaryText!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LocationIllustration extends StatelessWidget {
  const _LocationIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86,
    height: 66,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.map_outlined, size: 66, color: Colors.grey.shade400),
        const Positioned(
          top: 0,
          child: Icon(Icons.location_on_outlined, size: 40, color: _secondary),
        ),
        const Positioned(
          left: 2,
          top: 1,
          child: Icon(Icons.auto_awesome, size: 12, color: _secondary),
        ),
        const Positioned(
          right: 2,
          top: 12,
          child: Icon(Icons.auto_awesome, size: 11, color: _secondary),
        ),
      ],
    ),
  );
}

class _CancellationDialog extends StatelessWidget {
  const _CancellationDialog({required this.preview, required this.onConfirm});

  final PassengerCancellationInfo preview;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final lastChance = preview.blocksAccount;
    final title = lastChance
        ? 'Это может повлиять на ваш\nаккаунт'
        : 'Отменить бронирование?';
    final message = !preview.isViolation
        ? 'Вы уверены, что хотите отменить бронирование?'
        : lastChance
        ? 'Вы уже отменили одну поездку за последние 30 дней. Бронирование новых поездок будет недоступно в течении 30 дней.'
        : 'Две отмены в течение 30 дней приведут к автоматической блокировке аккаунта на 30 дней.';
    return Dialog(
      key: const ValueKey('booking-cancellation-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _secondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (preview.isViolation) ...[
              const SizedBox(height: 18),
              Container(
                key: const ValueKey('booking-cancellation-warning'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: lastChance
                      ? const Color(0xFFFFFBED)
                      : const Color(0xFFF8F8F8),
                  border: Border.all(
                    color: lastChance
                        ? const Color(0xFFE3B600)
                        : const Color(0xFFE9EAEB),
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: lastChance
                    ? const Row(
                        children: [
                          Icon(Icons.error, color: Color(0xFFE3B600), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'У вас уже была одна отмена за последние 30 дней',
                              style: TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Отмен за 30 дней',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${preview.violationsLastPeriod + 1} / 2',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('booking-cancellation-keep'),
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(lastChance ? 'Не отменять' : 'Не отменять'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('booking-cancellation-confirm'),
              onPressed: () async {
                Navigator.of(context).pop();
                await onConfirm();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: const Color(0xFFF5434B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(lastChance ? 'Всё равно отменить' : 'Да, отменить'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_profile.dart' show tripsLabel;
import '../../domain/driver_trip.dart';
import '../widgets/driver_header.dart';
import '../widgets/driver_style.dart';
import 'driver_trip_page.dart' show PassengerRouteCard;

/// "Профиль пассажира" from the driver's trip. Before the request is
/// accepted: name and rating. After: also the phone and the passenger's
/// part of the route. "Написать" is always there.
class PassengerProfilePage extends StatelessWidget {
  const PassengerProfilePage({super.key, required this.booking, this.onChat});

  final TripBooking booking;
  final VoidCallback? onChat;

  /// The driver accepted it (or it was instant): the contact is shared.
  static bool isAccepted(TripBookingStatus status) =>
      status == TripBookingStatus.awaitingPayment ||
      status == TripBookingStatus.paid ||
      status == TripBookingStatus.completed;

  Future<void> _copyPhone(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Номер скопирован')));
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final p = b.passenger;
    final accepted = isAccepted(b.status);
    final phone = accepted ? b.phone : null;
    final showRoute =
        accepted && b.boardAddress != null && b.alightAddress != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DriverColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DriverHeader(title: 'Профиль пассажира'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DriverColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _Avatar(url: p.avatarUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p.shortName,
                                  style: DriverText.label,
                                ),
                              ),
                            ],
                          ),
                          if (phone != null) ...[
                            const SizedBox(height: 12),
                            _Tile(
                              key: const ValueKey('passenger-phone'),
                              label: 'Номер телефона',
                              onTap: () => _copyPhone(context, phone),
                              child: Text(
                                formatPhone(phone),
                                style: DriverText.label,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _Tile(
                            label: 'Рейтинг поездок',
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFFFFB800),
                                ),
                                Text(p.ratingLabel, style: DriverText.label),
                                if (p.reviewsCount == 0)
                                  const Text(
                                    '· нет отзывов',
                                    style: DriverText.label,
                                  ),
                                Text(
                                  '· ${tripsLabel(p.completedTrips)}',
                                  style: DriverText.label,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showRoute) ...[
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Маршрут пассажира',
                          style: DriverText.label,
                        ),
                      ),
                      PassengerRouteCard(
                        key: const ValueKey('passenger-route'),
                        board: b.boardAddress!,
                        alight: b.alightAddress!,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('passenger-chat'),
                    onPressed: onChat,
                    style: FilledButton.styleFrom(
                      backgroundColor: DriverColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: DriverText.label,
                    ),
                    child: const Text('Написать'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+79001110001" → "+7 900 111 00 01"; other formats are left as is.
String formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11 || !phone.startsWith('+7')) return phone;
  return '+7 ${digits.substring(1, 4)} ${digits.substring(4, 7)} '
      '${digits.substring(7, 9)} ${digits.substring(9)}';
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

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DriverColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: DriverColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
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
              child,
            ],
          ),
        ),
      ),
    );
  }
}

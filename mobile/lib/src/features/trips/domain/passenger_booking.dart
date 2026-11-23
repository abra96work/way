class PassengerSeatBookingDraft {
  const PassengerSeatBookingDraft({
    required this.tripId,
    required this.fromPosition,
    required this.toPosition,
    required this.seats,
    required this.extras,
  });

  final String tripId;
  final int fromPosition;
  final int toPosition;
  final int seats;
  final List<String> extras;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trip_id': tripId,
    'kind': 'seat',
    'from_position': fromPosition,
    'to_position': toPosition,
    'seats': seats,
    'extras': extras,
  };
}

class PassengerBooking {
  const PassengerBooking({
    required this.id,
    required this.tripId,
    required this.status,
    required this.price,
    required this.commission,
    required this.payToDriver,
    required this.canPay,
    required this.canCancel,
    this.isRefunded = false,
  });

  final String id;
  final String tripId;
  final String status;
  final int price;
  final int commission;
  final int payToDriver;
  final bool canPay;
  final bool canCancel;
  final bool isRefunded;

  bool get isPaid => status == 'paid' || status == 'completed';

  factory PassengerBooking.fromJson(Map<String, dynamic> json) {
    final trip = _map(json['trip']);
    final price = _map(json['price']);
    final payment = _map(json['payment']);
    return PassengerBooking(
      id: json['id'] as String? ?? '',
      tripId: trip['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      price: (price['passenger_price'] as num?)?.toInt() ?? 0,
      commission: (payment['pay_online'] as num?)?.toInt() ?? 0,
      payToDriver: (payment['pay_to_driver'] as num?)?.toInt() ?? 0,
      canPay: json['can_pay'] == true,
      canCancel: json['can_cancel'] == true,
      isRefunded: payment['is_refunded'] == true,
    );
  }
}

class PassengerCancellationInfo {
  const PassengerCancellationInfo({
    required this.isViolation,
    required this.violationsLastPeriod,
    required this.blocksAccount,
    this.warning,
    this.blockedUntil,
  });

  final bool isViolation;
  final int violationsLastPeriod;
  final bool blocksAccount;
  final String? warning;
  final DateTime? blockedUntil;

  factory PassengerCancellationInfo.fromJson(Map<String, dynamic> json) =>
      PassengerCancellationInfo(
        isViolation: json['is_violation'] == true,
        violationsLastPeriod:
            (json['violations_last_period'] as num?)?.toInt() ?? 0,
        blocksAccount: json['blocks_account'] == true,
        warning: json['warning'] as String?,
        blockedUntil: DateTime.tryParse(json['blocked_until'] as String? ?? ''),
      );
}

class PassengerCancellationResult {
  const PassengerCancellationResult({
    required this.booking,
    required this.sanction,
  });

  final PassengerBooking booking;
  final PassengerCancellationInfo sanction;

  factory PassengerCancellationResult.fromJson(Map<String, dynamic> json) =>
      PassengerCancellationResult(
        booking: PassengerBooking.fromJson(_map(json['booking'])),
        sanction: PassengerCancellationInfo.fromJson(_map(json['sanction'])),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

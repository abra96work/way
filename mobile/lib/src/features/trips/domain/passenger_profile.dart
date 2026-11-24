class PassengerProfile {
  const PassengerProfile({
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.rating,
    required this.reviewsCount,
    required this.completedTrips,
    required this.phone,
  });

  final String firstName;
  final String? lastName;
  final String? avatarUrl;
  final double rating;
  final int reviewsCount;
  final int completedTrips;
  final String phone;

  String get displayName => [
    firstName,
    if (lastName != null && lastName!.trim().isNotEmpty) lastName!.trim(),
  ].join(' ').trim();

  String get ratingLabel => rating.toStringAsFixed(1).replaceAll('.', ',');

  factory PassengerProfile.fromJson(
    Map<String, dynamic> json, {
    required String mediaBaseUrl,
  }) {
    final avatar = json['avatar_url'] as String?;
    return PassengerProfile(
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      avatarUrl: avatar == null || avatar.isEmpty
          ? null
          : avatar.startsWith('http://') || avatar.startsWith('https://')
          ? avatar
          : '$mediaBaseUrl$avatar',
      rating: (json['rating'] as num?)?.toDouble() ?? 5,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      completedTrips: (json['completed_trips'] as num?)?.toInt() ?? 0,
      phone: json['phone'] as String? ?? '',
    );
  }
}

String passengerTripsLabel(int value) {
  final word = value % 10 == 1 && value % 100 != 11
      ? 'поездка'
      : value % 10 >= 2 &&
            value % 10 <= 4 &&
            (value % 100 < 12 || value % 100 > 14)
      ? 'поездки'
      : 'поездок';
  return '$value $word';
}

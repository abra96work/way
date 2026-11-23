import 'package:flutter/foundation.dart';

/// The signed-in user as the driver's profile shows it (`GET /me`).
@immutable
class DriverProfile {
  const DriverProfile({
    required this.firstName,
    this.lastName,
    this.avatarUrl,
    this.rating = 5,
    this.reviewsCount = 0,
    this.completedTrips = 0,
  });

  /// [mediaBaseUrl] turns the API's relative `/media/...` path into a URL.
  factory DriverProfile.fromJson(
    Map<String, dynamic> json, {
    String mediaBaseUrl = '',
  }) {
    final avatar = json['avatar_url'] as String?;
    return DriverProfile(
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      avatarUrl: avatar == null ? null : '$mediaBaseUrl$avatar',
      rating: (json['rating'] as num?)?.toDouble() ?? 5,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      completedTrips: json['completed_trips'] as int? ?? 0,
    );
  }

  final String firstName;
  final String? lastName;
  final String? avatarUrl;

  /// Stars from reviews; 5.0 while there are none.
  final double rating;
  final int reviewsCount;
  final int completedTrips;

  /// "4,8" — Russian decimal comma.
  String get ratingLabel => rating.toStringAsFixed(1).replaceAll('.', ',');
}

/// "1 поездка", "3 поездки", "120 поездок".
String tripsLabel(int n) {
  final word = n % 10 == 1 && n % 100 != 11
      ? 'поездка'
      : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)
      ? 'поездки'
      : 'поездок';
  return '$n $word';
}

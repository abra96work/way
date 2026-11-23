/// Error with a message ready to show (the backend's Russian `message`),
/// plus its machine `code` and `details` for screens that react to them.
class DriverApiException implements Exception {
  const DriverApiException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() => message;
}

/// `details` of the `daily_trip_limit` error (`POST /trips`).
class DailyTripLimit {
  const DailyTripLimit({
    required this.date,
    required this.published,
    required this.thereUsed,
    required this.backUsed,
    this.thereLimit = 1,
    this.backLimit = 1,
  });

  /// Returns `null` when [error] is not the daily limit.
  static DailyTripLimit? from(DriverApiException error) {
    final d = error.details;
    if (error.code != 'daily_trip_limit' || d is! Map) return null;
    final there = d['there'] as Map? ?? const {};
    final back = d['back'] as Map? ?? const {};
    return DailyTripLimit(
      date: DateTime.tryParse(d['date'] as String? ?? ''),
      published: d['published'] as int? ?? 0,
      thereUsed: there['used'] as int? ?? 0,
      thereLimit: there['limit'] as int? ?? 1,
      backUsed: back['used'] as int? ?? 0,
      backLimit: back['limit'] as int? ?? 1,
    );
  }

  /// Local day the limit is about (the trip's departure day).
  final DateTime? date;
  final int published;
  final int thereUsed;
  final int thereLimit;
  final int backUsed;
  final int backLimit;
}

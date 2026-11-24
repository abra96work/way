class PassengerApiException implements Exception {
  const PassengerApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

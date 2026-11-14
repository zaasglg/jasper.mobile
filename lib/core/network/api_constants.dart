abstract final class ApiConstants {
  static const String baseUrl = 'https://josparbee.kz/api/';

  static final Uri origin = Uri.parse(baseUrl).resolve('/');

  static bool isSameOrigin(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == origin.scheme &&
        uri.host == origin.host &&
        uri.port == origin.port;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

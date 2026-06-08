import 'package:dio/dio.dart';

/// Domain error surfaced to providers/UI for HTTP and network failures.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  /// Human-readable message.
  final String message;

  /// HTTP status code when the request reached the server.
  final int? statusCode;

  /// Backend error slug (e.g. `invalid_credentials`) when present.
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';

  /// Maps a [DioException] (transport-level: timeouts, DNS, no connection)
  /// to a friendly message.
  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Request timed out. Check your connection.');
      case DioExceptionType.connectionError:
        return const ApiException('Could not reach the server.');
      default:
        return ApiException(
          error.message ?? 'Network error.',
          statusCode: error.response?.statusCode,
        );
    }
  }
}

/// Extracts the backend `error` slug from a response body when present.
String? errorCodeFromBody(Object? data) {
  if (data is Map && data['error'] is String) {
    return data['error'] as String;
  }
  return null;
}

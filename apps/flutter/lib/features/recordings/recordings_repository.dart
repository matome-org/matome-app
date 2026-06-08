import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import 'recording.dart';

/// Reads the authenticated user's recordings from the Core API.
class RecordingsRepository {
  RecordingsRepository({required ApiClient apiClient}) : this._(apiClient);

  RecordingsRepository._(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/recordings` (Bearer). Returns the parsed list.
  Future<List<Recording>> fetchRecordings() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/recordings',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) {
        throw const ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      if (status != 200) {
        throw ApiException(
          'Failed to load recordings.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final data = response.data ?? const <String, dynamic>{};
      return Recording.listFromEnvelope(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

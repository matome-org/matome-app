import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import 'matome.dart';

/// Drives the authenticated user's Matomes against the Core API (task #1377).
///
/// Mirrors [RecordingsRepository]: a thin Bearer-authed HTTP surface with no
/// local state. Space-scoped sync (.docs/internal/architecture.md §11 (D4)) decides WHEN to call these — only
/// a Matome filed into a Space is ever pushed here. Plain generative constructor
/// so tests can subclass/fake it the same way the recordings repo allows.
class MatomesRepository {
  // Plain generative constructor (no redirect) so tests can subclass it to stub
  // HTTP, mirroring [RecordingsRepository].
  // ignore: prefer_initializing_formals
  MatomesRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `GET /api/matomes` (Bearer). The user's triaged Matomes.
  Future<List<Matome>> fetchMatomes() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/matomes',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 200) {
        throw ApiException(
          'Failed to load matomes.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return Matome.listFromEnvelope(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/matomes` (Bearer). Creates the remote Matome and returns it
  /// (carrying the freshly-minted Core id reconciled into `matomes.core_id`).
  Future<Matome> createMatome({
    required String title,
    required int workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/matomes',
        data: <String, dynamic>{
          'title': title,
          'workspace_id': workspaceId,
          'happened_at': ?happenedAt?.toUtc().toIso8601String(),
          'description': ?description,
          'aggregated_summary': ?aggregatedSummary,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 201 && status != 200) {
        throw ApiException(
          'Failed to create matome.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return _matomeFromBody(response.data, status);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `PATCH /api/matomes/:id` (Bearer). Persists edits; only provided fields are
  /// sent. [workspaceId] re-files the Matome into a different Space.
  Future<Matome> updateMatome(
    int id, {
    String? title,
    int? workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/api/matomes/$id',
        data: <String, dynamic>{
          'title': ?title,
          'workspace_id': ?workspaceId,
          'happened_at': ?happenedAt?.toUtc().toIso8601String(),
          'description': ?description,
          'aggregated_summary': ?aggregatedSummary,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 200) {
        throw ApiException(
          'Failed to update matome.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return _matomeFromBody(response.data, status);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/matomes/:id/archive` (Bearer). Soft-deletes the remote Matome
  /// (stamps `archived_at`) and returns it. Recoverable via [restoreMatome] —
  /// data and local files are retained.
  Future<Matome> archiveMatome(int id) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/matomes/$id/archive',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 200) {
        throw ApiException(
          'Failed to archive matome.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return _matomeFromBody(response.data, status);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/matomes/:id/restore` (Bearer). Un-archives the remote Matome
  /// (clears `archived_at`) and returns it.
  Future<Matome> restoreMatome(int id) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/matomes/$id/restore',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 200) {
        throw ApiException(
          'Failed to restore matome.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return _matomeFromBody(response.data, status);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `DELETE /api/matomes/:id` (Bearer). 204/200/404 are all success.
  Future<void> deleteMatome(int id) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>('/api/matomes/$id');
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 204 && status != 200 && status != 404) {
        throw ApiException(
          'Failed to delete matome.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/matomes/:matomeId/contacts {contact_id, role}` (Bearer).
  /// Attaches a contact edge (201). 200 (idempotent re-attach) is also success.
  Future<void> attachContact({
    required int matomeId,
    required int contactId,
    String role = 'attendee',
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/api/matomes/$matomeId/contacts',
        data: <String, dynamic>{'contact_id': contactId, 'role': role},
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 201 && status != 200) {
        throw ApiException(
          'Failed to attach contact.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `DELETE /api/matomes/:matomeId/contacts/:contactId` (Bearer). Detaches the
  /// edge (204). 200/404 (already gone) are also treated as success.
  Future<void> detachContact({
    required int matomeId,
    required int contactId,
  }) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/api/matomes/$matomeId/contacts/$contactId',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 204 && status != 200 && status != 404) {
        throw ApiException(
          'Failed to detach contact.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  static const _unauthorized = ApiException(
    'Session expired. Please sign in again.',
    statusCode: 401,
    code: 'unauthorized',
  );

  Matome _matomeFromBody(Map<String, dynamic>? data, int status) {
    final raw = data?['matome'];
    if (raw is! Map<String, dynamic>) {
      throw ApiException(
        'Malformed matome response.',
        statusCode: status,
        code: 'malformed_response',
      );
    }
    return Matome.fromJson(raw);
  }
}

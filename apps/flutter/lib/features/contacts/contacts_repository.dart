import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import 'contact.dart';

/// Drives the authenticated user's Contacts against the Core API (task #1377).
///
/// Mirrors [RecordingsRepository] / [MatomesRepository]: a thin Bearer-authed
/// HTTP surface, no local state. Plain generative constructor so tests can
/// subclass/fake it.
class ContactsRepository {
  // Plain generative constructor (no redirect) so tests can subclass it to stub
  // HTTP, mirroring [RecordingsRepository].
  // ignore: prefer_initializing_formals
  ContactsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `GET /api/contacts` (Bearer).
  Future<List<Contact>> fetchContacts() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/contacts',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 200) {
        throw ApiException(
          'Failed to load contacts.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return Contact.listFromEnvelope(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/contacts` (Bearer). Creates and returns the remote Contact (its
  /// Core id reconciles into `contacts.core_id`).
  Future<Contact> createContact({
    required String displayName,
    String? email,
    String? phone,
    String? company,
    String? title,
    String? metadata,
    String? linkedUserId,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/contacts',
        data: <String, dynamic>{
          'display_name': displayName,
          'email': ?email,
          'phone': ?phone,
          'company': ?company,
          'title': ?title,
          'metadata': ?metadata,
          'linked_user_id': ?linkedUserId,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 201 && status != 200) {
        throw ApiException(
          'Failed to create contact.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return _contactFromBody(response.data, status);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `PUT /api/contacts/:id` (Bearer). Only provided fields are sent.
  Future<Contact> updateContact(
    int id, {
    String? displayName,
    String? email,
    String? phone,
    String? company,
    String? title,
    String? metadata,
    String? linkedUserId,
  }) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/api/contacts/$id',
        data: <String, dynamic>{
          'display_name': ?displayName,
          'email': ?email,
          'phone': ?phone,
          'company': ?company,
          'title': ?title,
          'metadata': ?metadata,
          'linked_user_id': ?linkedUserId,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 200) {
        throw ApiException(
          'Failed to update contact.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return _contactFromBody(response.data, status);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `DELETE /api/contacts/:id` (Bearer). 204/200/404 are all success.
  Future<void> deleteContact(int id) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/api/contacts/$id',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) throw _unauthorized;
      if (status != 204 && status != 200 && status != 404) {
        throw ApiException(
          'Failed to delete contact.',
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

  Contact _contactFromBody(Map<String, dynamic>? data, int status) {
    final raw = data?['contact'];
    if (raw is! Map<String, dynamic>) {
      throw ApiException(
        'Malformed contact response.',
        statusCode: status,
        code: 'malformed_response',
      );
    }
    return Contact.fromJson(raw);
  }
}

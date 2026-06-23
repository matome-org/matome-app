import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';

/// A Space (workspace) as Core returns it. Carries the freshly-minted numeric
/// Core id — the value the local space is RE-KEYED to on promotion so the
/// existing space-scoped matome/recording sync (`int.tryParse(spaceId)`) drains
/// its items (plan #102 W4 / #1499).
class CoreSpace {
  const CoreSpace({required this.id, required this.name, this.ownerId});

  /// The numeric Core workspace id (`workspaces.id`).
  final int id;
  final String name;

  /// The owning user's stable Core id (`workspaces.owner_id`). Returned so the
  /// client can assert Core stamped the space to the authenticated owner.
  final String? ownerId;

  static CoreSpace fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return CoreSpace(
      id: id is int ? id : int.parse(id.toString()),
      name: (json['name'] ?? '').toString(),
      ownerId: json['owner_id']?.toString(),
    );
  }
}

/// Drives the authenticated user's Spaces (workspaces) against the Core API
/// (plan #102 W4 / #1499). A thin Bearer-authed HTTP surface with no local
/// state, mirroring [MatomesRepository] / [RecordingsRepository].
///
/// OWNER-SCOPED ON CORE (verified, spec R3.6): `create` hits
/// `POST /api/spaces`, whose controller stamps `owner_id` from
/// `conn.assigns.current_user` and whose every read/write is filtered by
/// `owner_id == current_user` (services/api/lib/matome_api/content.ex:31). The
/// client cannot create a space owned by another user; the client-side
/// owner-scope gate ([SyncPolicy.can] with `Operation.spacePromote`) is the
/// mirror that refuses to even attempt the call for a space the caller does not
/// own.
class SpacesRepository {
  // Plain generative constructor (no redirect) so tests can subclass it to stub
  // HTTP, mirroring the other repositories.
  // ignore: prefer_initializing_formals
  SpacesRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `POST /api/spaces` (Bearer). Creates the remote Space owned by the
  /// authenticated user and returns it carrying the minted numeric Core id.
  Future<CoreSpace> createSpace({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/spaces',
        data: <String, dynamic>{
          'name': name,
          'description': ?description,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 401) {
        throw const ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      if (status != 201 && status != 200) {
        throw ApiException(
          'Failed to create space.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final body = response.data ?? const <String, dynamic>{};
      final workspace = body['workspace'];
      if (workspace is! Map<String, dynamic>) {
        throw const ApiException(
          'Malformed space create response.',
          code: 'malformed_response',
        );
      }
      return CoreSpace.fromJson(workspace);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

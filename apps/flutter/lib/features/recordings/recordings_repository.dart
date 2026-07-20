import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import '../documents/document_open_policy.dart';
import '../documents/document_open_service.dart';
import 'recording.dart';
import 'presigned_upload_transport.dart';
import 'upload_descriptor.dart';

/// Reads and drives the authenticated user's file items against the Core API.
///
/// Beyond listing, this owns Core's verified single/multipart upload client and
/// the optional process-acceptance request. Device queue state remains in Drift;
/// signed storage requests are deliberately memory-only.
class RecordingsRepository {
  // Plain generative constructor (no redirect) so tests can subclass it to stub
  // the presigned-PUT upload, which otherwise opens its own bare Dio.
  // ignore: prefer_initializing_formals
  RecordingsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `GET /api/items` (Bearer). Returns the parsed file-item list.
  Future<List<Recording>> fetchRecordings() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/items',
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
          'Failed to load items.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final data = response.data ?? const <String, dynamic>{};
      return Recording.listFromItemsEnvelope(data);
    } on DioException catch (e, st) {
      AppLog.error(LogCat.upload, 'fetchRecordings: transport failed', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/items/{id}` (Bearer). The current-run polling source.
  ///
  /// Returns `null` on 404 so the poll loop can treat a missing recording as a
  /// transient miss rather than crashing.
  Future<Recording?> fetchRecording(int id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/items/$id',
      );
      final status = response.statusCode ?? 0;
      if (status == 404) return null;
      if (status == 401) {
        throw const ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      if (status != 200) {
        throw ApiException(
          'Failed to load item.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final raw = response.data?['item'];
      if (raw is! Map<String, dynamic>) return null;
      return Recording.fromItemJson(raw);
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) return null;
      AppLog.error(
        LogCat.upload,
        'fetchRecording: transport failed for id=$id',
        e,
        st,
      );
      throw ApiException.fromDio(e);
    }
  }

  /// Creates a pending file item and returns its W0 upload envelope.
  Future<RecordingCreateResult> createRecording({
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
  }) {
    throw const ApiException(
      'A reconciled matome is required to create an item.',
      code: 'missing_matome_id',
    );
  }

  Future<RecordingCreateResult> createItemRecording({
    required String title,
    required int matomeId,
    required String clientId,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
    String? checksumSha256,
    String? filename,
    String? contentType,
  }) async {
    AppLog.event(LogCat.upload, 'createRecording: $title');
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/matomes/$matomeId/items',
        data: <String, dynamic>{
          'client_id': clientId,
          'item_type': 'file',
          'title': title,
          'filename': filename ?? title,
          'media_type': mediaType,
          'workspace_id': ?workspaceId,
          'metadata': <String, dynamic>{'badge': ?badge},
          'duration': ?durationSeconds,
          // #1471: declare the upload size in bytes. Core SigV4-signs it into the
          // presigned PUT AND persists it as `byte_size` so the Files view shows
          // a real size. Omitted when unknown (legacy/streamed callers).
          'content_length': ?contentLength,
          'content_type': ?contentType,
          'checksum_sha256': ?checksumSha256,
          'transport': _uploadTransport,
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
      if (status != 201) {
        throw ApiException(
          'Failed to create recording.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final data = response.data ?? const <String, dynamic>{};
      final recordingRaw = data['item'];
      final uploadRaw = data['upload'];
      if (recordingRaw is! Map<String, dynamic> ||
          uploadRaw is! Map<String, dynamic>) {
        throw const ApiException(
          'Malformed create-recording response.',
          statusCode: 201,
          code: 'malformed_response',
        );
      }
      return RecordingCreateResult(
        recording: Recording.fromItemJson(recordingRaw),
        upload: UploadDescriptor.fromJson(uploadRaw),
      );
    } on DioException catch (e, st) {
      AppLog.error(LogCat.upload, 'createRecording: transport failed', e, st);
      throw ApiException.fromDio(e);
    }
  }

  Future<Recording> createTextItem({
    required String clientId,
    required String body,
    int? matomeId,
    int? workspaceId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/items/text',
        data: <String, dynamic>{
          'client_id': clientId,
          'body': body,
          'matome_id': ?matomeId,
          'workspace_id': ?workspaceId,
          'title': ?title,
          'metadata': ?metadata,
        },
      );
      if (response.statusCode == 409 &&
          _textErrorCode(response.data) == 'client_id_conflict') {
        final current = response.data?['item'];
        throw TextClientIdConflict(
          current is Map<String, dynamic>
              ? Recording.fromItemJson(current)
              : null,
        );
      }
      return _textItemResponse(
        response,
        operation: 'create',
        statuses: {200, 201},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Recording> updateTextItem(
    int id, {
    required String body,
    required int expectedSourceRevision,
  }) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/api/items/$id/text',
        data: <String, dynamic>{
          'body': body,
          'expected_source_revision': expectedSourceRevision,
        },
      );
      if (response.statusCode == 409 &&
          _textErrorCode(response.data) == 'version_conflict') {
        final current = response.data?['item'];
        throw TextVersionConflict(
          current is Map<String, dynamic>
              ? Recording.fromItemJson(current)
              : null,
        );
      }
      return _textItemResponse(response, operation: 'update', statuses: {200});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteTextItem(
    int id, {
    required int expectedSourceRevision,
  }) async {
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/api/items/$id/text',
        data: <String, dynamic>{
          'expected_source_revision': expectedSourceRevision,
        },
      );
      final status = response.statusCode ?? 0;
      if (status == 409 &&
          _textErrorCode(response.data) == 'version_conflict') {
        final current = response.data is Map ? response.data!['item'] : null;
        throw TextVersionConflict(
          current is Map<String, dynamic>
              ? Recording.fromItemJson(current)
              : null,
        );
      }
      if (status != 200 && status != 204 && status != 404) {
        throw ApiException(
          'Failed to delete text item.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Recording _textItemResponse(
    Response<Map<String, dynamic>> response, {
    required String operation,
    required Set<int> statuses,
  }) {
    final status = response.statusCode ?? 0;
    final raw = response.data?['item'];
    if (!statuses.contains(status) || raw is! Map<String, dynamic>) {
      throw ApiException(
        'Failed to $operation text item.',
        statusCode: status,
        code: errorCodeFromBody(response.data),
      );
    }
    return Recording.fromItemJson(raw);
  }

  String? _textErrorCode(Object? data) {
    final legacy = errorCodeFromBody(data);
    if (legacy != null) return legacy;
    if (data is! Map) return null;
    if (data['code'] is String) return data['code'] as String;
    final error = data['error'];
    return error is Map && error['code'] is String
        ? error['code'] as String
        : null;
  }

  /// Creates or resumes Core's active upload generation with fresh credentials.
  Future<UploadDescriptor> requestUpload(
    int itemId, {
    required int inputRevision,
    required int byteSize,
    required String checksumSha256,
    String? contentType,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/items/$itemId/uploads',
        data: <String, dynamic>{
          'contract_version': '1',
          'idempotency_key': 'item-$itemId-rev-$inputRevision-upload',
          'input_revision': inputRevision,
          'mode': 'auto',
          'transport': _uploadTransport,
          'byte_size': byteSize,
          'content_type': ?contentType,
          'checksum_sha256': checksumSha256,
        },
      );
      return _uploadFromResponse(response, operation: 'request upload');
    } on DioException catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'requestUpload: transport failed',
        error,
        stack,
      );
      throw ApiException.fromDio(error);
    }
  }

  static String get _uploadTransport =>
      kIsWeb ? 'browser_stream' : 'direct_signed_length';

  Future<UploadDescriptor> inspectUpload(String uploadId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/v1/uploads/$uploadId',
      );
      return _uploadFromResponse(response, operation: 'inspect upload');
    } on DioException catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'inspectUpload: transport failed',
        error,
        stack,
      );
      throw ApiException.fromDio(error);
    }
  }

  Future<UploadPartDescriptor> presignUploadPart(
    String uploadId, {
    required int partNumber,
    required String checksumSha256,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/uploads/$uploadId/parts/$partNumber/presign',
        data: <String, dynamic>{'checksum_sha256': checksumSha256},
      );
      final status = response.statusCode ?? 0;
      final raw = response.data?['part'];
      if (status == 404) {
        throw const DocumentDescriptorUnavailableException();
      }
      if (status != 200 || raw is! Map<String, dynamic>) {
        throw ApiException(
          'Failed to presign upload part.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      return UploadPartDescriptor.fromJson(raw);
    } on DioException catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'presignUploadPart: transport failed',
        error,
        stack,
      );
      throw ApiException.fromDio(error);
    }
  }

  Future<UploadDescriptor> completeUpload(
    String uploadId, {
    required int uploadGeneration,
    required String checksumSha256,
    String? etag,
    List<UploadPart> parts = const [],
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/uploads/$uploadId/complete',
        data: <String, dynamic>{
          'contract_version': '1',
          'upload_generation': uploadGeneration,
          'checksum_sha256': checksumSha256,
          'etag': ?etag,
          if (parts.isNotEmpty)
            'parts': parts.map((part) => part.toCompleteJson()).toList(),
        },
      );
      return _uploadFromResponse(response, operation: 'complete upload');
    } on DioException catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'completeUpload: transport failed',
        error,
        stack,
      );
      throw ApiException.fromDio(error);
    }
  }

  UploadDescriptor _uploadFromResponse(
    Response<Map<String, dynamic>> response, {
    required String operation,
  }) {
    final status = response.statusCode ?? 0;
    final raw = response.data?['upload'];
    if (status != 200 || raw is! Map<String, dynamic>) {
      throw ApiException(
        'Failed to $operation.',
        statusCode: status,
        code: errorCodeFromBody(response.data),
      );
    }
    return UploadDescriptor.fromJson(raw);
  }

  /// Stream-upload variant taking a raw byte stream + known [length].
  /// Exposed for callers that already hold a stream (and for testing with a
  /// mocked adapter).
  Future<void> uploadStream(
    UploadDescriptor upload,
    Stream<List<int>> stream,
    int length,
  ) async {
    final request = upload.request;
    if (request == null) {
      throw const ApiException(
        'Upload credentials are missing.',
        code: 'malformed_response',
      );
    }
    await _uploadRequest(request, stream, length, requireEtag: false);
  }

  /// Uploads exactly the supplied authenticated plaintext stream and returns
  /// the provider ETag used by Core's completion verification.
  Future<String> uploadStreamRange(
    UploadRequest request,
    Stream<List<int>> stream,
    int length,
  ) async {
    if (length <= 0) {
      throw const ApiException(
        'Invalid upload stream length.',
        code: 'invalid_local_data',
      );
    }
    return _uploadRequest(request, stream, length, requireEtag: true);
  }

  Future<String> _uploadRequest(
    UploadRequest request,
    Stream<List<int>> stream,
    int length, {
    required bool requireEtag,
  }) async {
    return sendPresignedUpload(
      request,
      stream,
      length,
      requireEtag: requireEtag,
    );
  }

  /// `PATCH /api/items/{id}` (Bearer). Persists edits to the Core item.
  ///
  /// Mirrors apps/mobile `coreApiClient.patchRecording`. Only the provided
  /// fields are sent. Returns the updated [Recording] echoed by the backend.
  ///
  /// [workspaceId] moves the recording into a space (or back to the Inbox when
  /// `clearWorkspace` is true → sends `workspace_id: null`). The Core changeset
  /// casts `workspace_id` and FK-validates it against a workspace the caller
  /// owns, so a move-to-space survives a later list sync.
  Future<Recording> updateRecording(
    int id, {
    String? transcript,
    String? notes,
    String? summary,
    String? title,
    String? badge,
    int? workspaceId,
    int? matomeId,
    bool clearWorkspace = false,
  }) async {
    AppLog.event(LogCat.upload, 'updateRecording: id=$id');
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/api/items/$id',
        data: <String, dynamic>{
          // `notes` (user-owned, task #1432) is sent independently of
          // `transcript` (machine-owned) so a notes edit never clobbers the
          // machine transcript. Both null-omit (`?`) like the other fields.
          'transcript': ?transcript,
          'notes': ?notes,
          'summary': ?summary,
          'title': ?title,
          'badge': ?badge,
          // child-before-parent (task #1377): the recording's remote matome_id
          // is only sent once its Matome has a Core id; never null-clobbered.
          'matome_id': ?matomeId,
          if (clearWorkspace)
            'workspace_id': null
          else
            'workspace_id': ?workspaceId,
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
      if (status != 200) {
        throw ApiException(
          'Failed to update recording.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final raw = response.data?['item'];
      if (raw is! Map<String, dynamic>) {
        throw const ApiException(
          'Malformed update response.',
          statusCode: 200,
          code: 'malformed_response',
        );
      }
      return Recording.fromItemJson(raw);
    } on DioException catch (e, st) {
      AppLog.error(
        LogCat.upload,
        'updateRecording: transport failed for id=$id',
        e,
        st,
      );
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /api/items/{id}` (Bearer). Removes the Core item.
  /// Treats 204/200 (and a 404 — already gone) as success.
  Future<void> deleteRecording(int id) async {
    AppLog.event(LogCat.upload, 'deleteRecording: id=$id');
    try {
      final response = await _apiClient.dio.delete<dynamic>('/api/items/$id');
      final status = response.statusCode ?? 0;
      if (status == 401) {
        throw const ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      if (status != 204 && status != 200 && status != 404) {
        throw ApiException(
          'Failed to delete recording.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) return;
      AppLog.error(
        LogCat.upload,
        'deleteRecording: transport failed for id=$id',
        e,
        st,
      );
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/items/{id}/download-url` (Bearer). Returns a presigned
  /// download URL for the stored audio, or `null` when none is available
  /// (404 / missing storage key). Used by Details (S2) as the playback source
  /// when there is no local file path.
  Future<String?> downloadUrl(int id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/items/$id/download-url',
      );
      final status = response.statusCode ?? 0;
      if (status == 404) return null;
      if (status == 401) {
        throw const ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      if (status != 200) return null;
      final download = response.data?['download'];
      if (download is Map && download['url'] is String) {
        return download['url'] as String;
      }
      return null;
    } on DioException catch (e, st) {
      AppLog.error(
        LogCat.upload,
        'downloadUrl: transport failed for id=$id',
        e,
        st,
      );
      throw ApiException.fromDio(e);
    }
  }

  /// Fetches one memory-only, owner-scoped document open descriptor. Signed
  /// URLs are never written to Drift or included in application logs.
  Future<DocumentOpenDescriptor> documentOpenDescriptor(int id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/items/$id/download-url',
      );
      final status = response.statusCode ?? 0;
      final raw = response.data?['download'];
      final code = errorCodeFromBody(response.data);
      if (status == 404 || (status == 422 && code == 'unsafe_file_type')) {
        throw const DocumentDescriptorUnavailableException();
      }
      if (status != 200 || raw is! Map<String, dynamic>) {
        throw ApiException(
          'Document is unavailable.',
          statusCode: status,
          code: code,
        );
      }
      final url = Uri.tryParse(raw['url'] as String? ?? '');
      final expiresAt = DateTime.tryParse(raw['expires_at'] as String? ?? '');
      final method = (raw['method'] as String? ?? '').toUpperCase();
      if (method != 'GET' || url == null || expiresAt == null) {
        throw const DocumentDescriptorUnavailableException();
      }
      return DocumentOpenDescriptor(
        method: method,
        url: url,
        expiresAt: expiresAt,
        openPolicy: DocumentOpenPolicy.fromWire(raw['open_policy'] as String?),
        action: switch (raw['action']) {
          'open' => DocumentOpenAction.open,
          'open_in_app' => DocumentOpenAction.openInApp,
          _ => DocumentOpenAction.download,
        },
      );
    } on DioException catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        'documentOpenDescriptor: Core request failed for id=$id',
        error,
        stack,
      );
      throw ApiException.fromDio(error);
    }
  }

  /// `POST /api/items/{id}/process` (Bearer). Enqueues processing.
  /// Returns the (still-pending) recording echoed by the backend.
  Future<Recording> enqueueProcessing(int id) async {
    AppLog.event(LogCat.upload, 'enqueueProcessing: id=$id');
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/items/$id/process',
      );
      final status = response.statusCode ?? 0;
      if (status == 401) {
        throw const ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
          code: 'unauthorized',
        );
      }
      // Core returns 202 Accepted with {recording, processing: {queued: true}}.
      if (status != 202 && status != 200) {
        throw ApiException(
          'Failed to enqueue processing.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final raw = response.data?['item'];
      if (raw is! Map<String, dynamic>) {
        throw const ApiException(
          'Malformed process response.',
          statusCode: 202,
          code: 'malformed_response',
        );
      }
      return Recording.fromItemJson(raw);
    } on DioException catch (e, st) {
      AppLog.error(
        LogCat.upload,
        'enqueueProcessing: transport failed for id=$id',
        e,
        st,
      );
      throw ApiException.fromDio(e);
    }
  }
}

class TextVersionConflict implements Exception {
  const TextVersionConflict(this.current);

  final Recording? current;
}

class TextClientIdConflict implements Exception {
  const TextClientIdConflict(this.current);

  final Recording? current;
}

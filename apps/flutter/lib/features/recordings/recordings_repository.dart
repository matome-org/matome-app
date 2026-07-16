import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import 'recording.dart';
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
  }) async {
    AppLog.event(LogCat.upload, 'createRecording: $title');
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/matomes/$matomeId/items',
        data: <String, dynamic>{
          'client_id': clientId,
          'item_type': 'file',
          'title': title,
          'media_type': mediaType,
          'workspace_id': ?workspaceId,
          'metadata': <String, dynamic>{'badge': ?badge},
          'duration': ?durationSeconds,
          // #1471: declare the upload size in bytes. Core SigV4-signs it into the
          // presigned PUT AND persists it as `byte_size` so the Files view shows
          // a real size. Omitted when unknown (legacy/streamed callers).
          'content_length': ?contentLength,
          'checksum_sha256': ?checksumSha256,
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

  /// Streams [file] to the presigned [upload] URL.
  ///
  /// Uses a streamed body (`file.openRead()`), so the audio is never fully
  /// loaded into memory. A bare [Dio] avoids injecting the Core Bearer token;
  /// the exact storage headers carried by the descriptor are sent instead.
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    final length = await file.length();
    AppLog.event(LogCat.upload, 'uploadFile: $length bytes -> presign');
    final request = upload.request;
    if (request == null) {
      throw const ApiException(
        'Upload credentials are missing.',
        code: 'malformed_response',
      );
    }
    await _uploadRequest(request, file.openRead(), length, requireEtag: false);
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

  /// Uploads exactly `[start, endExclusive)` and returns the provider ETag used
  /// by Core's completion verification.
  Future<String> uploadFileRange(
    UploadRequest request,
    File file, {
    required int start,
    required int endExclusive,
  }) async {
    final fileLength = await file.length();
    if (start < 0 || endExclusive <= start || endExclusive > fileLength) {
      throw const ApiException(
        'Invalid upload file range.',
        code: 'invalid_local_data',
      );
    }
    return _uploadRequest(
      request,
      file.openRead(start, endExclusive),
      endExclusive - start,
      requireEtag: true,
    );
  }

  Future<String> _uploadRequest(
    UploadRequest request,
    Stream<List<int>> stream,
    int length, {
    required bool requireEtag,
  }) async {
    final rawDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    try {
      final response = await rawDio.requestUri<void>(
        Uri.parse(request.url),
        data: stream,
        options: Options(
          method: request.method,
          headers: <String, dynamic>{
            ...request.headers,
            Headers.contentLengthHeader: length,
            // Core signs required checksum/length headers. Content type remains
            // generic because object identity preserves the original filename.
            Headers.contentTypeHeader: 'application/octet-stream',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ApiException(
          'Recording upload failed.',
          statusCode: status,
          code: 'upload_failed',
        );
      }
      final etag = response.headers.value('etag')?.replaceAll('"', '').trim();
      if (requireEtag && (etag == null || etag.isEmpty)) {
        throw const ApiException(
          'Upload response did not include an ETag.',
          code: 'upload_missing_etag',
        );
      }
      return etag ?? '';
    } on DioException catch (e, st) {
      AppLog.error(
        LogCat.upload,
        '_uploadStream: presigned PUT/POST failed',
        e,
        st,
      );
      throw ApiException.fromDio(e);
    } finally {
      rawDio.close(force: true);
    }
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

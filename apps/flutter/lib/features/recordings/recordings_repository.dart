import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
import '../../core/observability/app_log.dart';
import 'recording.dart';
import 'upload_descriptor.dart';

/// Reads and drives the authenticated user's recordings against the Core API.
///
/// Beyond listing, this owns the upload pipeline (F4):
/// `POST /api/recordings` (presign) -> PUT to the presigned URL ->
/// `POST /api/recordings/{id}/process`, plus the `GET /api/recordings/{id}`
/// poll used as the realtime-channel fallback.
class RecordingsRepository {
  // Plain generative constructor (no redirect) so tests can subclass it to stub
  // the presigned-PUT upload, which otherwise opens its own bare Dio.
  // ignore: prefer_initializing_formals
  RecordingsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

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
    } on DioException catch (e, st) {
      AppLog.error(LogCat.upload, 'fetchRecordings: transport failed', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/recordings/{id}` (Bearer). The realtime poll-fallback source.
  ///
  /// Returns `null` on 404 so the poll loop can treat a missing recording as a
  /// transient miss rather than crashing.
  Future<Recording?> fetchRecording(int id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/recordings/$id',
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
          'Failed to load recording.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final raw = response.data?['recording'];
      if (raw is! Map<String, dynamic>) return null;
      return Recording.fromJson(raw);
    } on DioException catch (e, st) {
      AppLog.error(
          LogCat.upload, 'fetchRecording: transport failed for id=$id', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/recordings` (Bearer). Creates a pending recording and returns
  /// it together with the presigned [UploadDescriptor].
  Future<RecordingCreateResult> createRecording({
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
  }) async {
    AppLog.event(LogCat.upload, 'createRecording: $title');
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/recordings',
        data: <String, dynamic>{
          'title': title,
          'status': 'pending',
          'media_type': mediaType,
          'duration': ?durationSeconds,
          'badge': ?badge,
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
      if (status != 201) {
        throw ApiException(
          'Failed to create recording.',
          statusCode: status,
          code: errorCodeFromBody(response.data),
        );
      }
      final data = response.data ?? const <String, dynamic>{};
      final recordingRaw = data['recording'];
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
        recording: Recording.fromJson(recordingRaw),
        upload: UploadDescriptor.fromJson(uploadRaw),
      );
    } on DioException catch (e, st) {
      AppLog.error(
          LogCat.upload, 'createRecording: transport failed', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// Streams [file] to the presigned [upload] URL.
  ///
  /// Uses a streamed body (`file.openRead()`), so the audio is never fully
  /// loaded into memory. The presigned URL is absolute and SigV4-signed over
  /// `host` only — we deliberately use a bare [Dio] (no base URL, no Bearer
  /// interceptor) so the auth header is not injected, which would invalidate
  /// the signature.
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    final length = await file.length();
    AppLog.event(LogCat.upload, 'uploadFile: $length bytes -> presign');
    final stream = file.openRead();
    await _uploadStream(upload, stream, length);
  }

  /// Stream-upload variant taking a raw byte stream + known [length].
  /// Exposed for callers that already hold a stream (and for testing with a
  /// mocked adapter).
  Future<void> uploadStream(
    UploadDescriptor upload,
    Stream<List<int>> stream,
    int length,
  ) =>
      _uploadStream(upload, stream, length);

  Future<void> _uploadStream(
    UploadDescriptor upload,
    Stream<List<int>> stream,
    int length,
  ) async {
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
        Uri.parse(upload.url),
        data: stream,
        options: Options(
          method: upload.isPost ? 'POST' : 'PUT',
          headers: <String, dynamic>{
            Headers.contentLengthHeader: length,
            // Binary media; the signature covers only the `host` header so
            // content-type is free-form and intentionally not signed.
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
    } on DioException catch (e, st) {
      AppLog.error(
          LogCat.upload, '_uploadStream: presigned PUT/POST failed', e, st);
      throw ApiException.fromDio(e);
    } finally {
      rawDio.close(force: true);
    }
  }

  /// `PATCH /api/recordings/{id}` (Bearer). Persists edits to the Core record.
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
        '/api/recordings/$id',
        data: <String, dynamic>{
          'transcript': ?transcript,
          'summary': ?summary,
          'title': ?title,
          'badge': ?badge,
          // child-before-parent (task #1377): the recording's remote matome_id
          // is only sent once its Matome has a Core id; never null-clobbered.
          'matome_id': ?matomeId,
          if (clearWorkspace) 'workspace_id': null else 'workspace_id': ?workspaceId,
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
      final raw = response.data?['recording'];
      if (raw is! Map<String, dynamic>) {
        throw const ApiException(
          'Malformed update response.',
          statusCode: 200,
          code: 'malformed_response',
        );
      }
      return Recording.fromJson(raw);
    } on DioException catch (e, st) {
      AppLog.error(
          LogCat.upload, 'updateRecording: transport failed for id=$id', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /api/recordings/{id}` (Bearer). Removes the Core record.
  /// Treats 204/200 (and a 404 — already gone) as success.
  Future<void> deleteRecording(int id) async {
    AppLog.event(LogCat.upload, 'deleteRecording: id=$id');
    try {
      final response = await _apiClient.dio.delete<dynamic>(
        '/api/recordings/$id',
      );
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
          LogCat.upload, 'deleteRecording: transport failed for id=$id', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /api/recordings/{id}/download-url` (Bearer). Returns a presigned
  /// download URL for the stored audio, or `null` when none is available
  /// (404 / missing storage key). Used by Details (S2) as the playback source
  /// when there is no local file path.
  Future<String?> downloadUrl(int id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/recordings/$id/download-url',
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
          LogCat.upload, 'downloadUrl: transport failed for id=$id', e, st);
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /api/recordings/{id}/process` (Bearer). Enqueues processing.
  /// Returns the (still-pending) recording echoed by the backend.
  Future<Recording> enqueueProcessing(int id) async {
    AppLog.event(LogCat.upload, 'enqueueProcessing: id=$id');
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/recordings/$id/process',
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
      final raw = response.data?['recording'];
      if (raw is! Map<String, dynamic>) {
        throw const ApiException(
          'Malformed process response.',
          statusCode: 202,
          code: 'malformed_response',
        );
      }
      return Recording.fromJson(raw);
    } on DioException catch (e, st) {
      AppLog.error(
          LogCat.upload, 'enqueueProcessing: transport failed for id=$id', e, st);
      throw ApiException.fromDio(e);
    }
  }
}

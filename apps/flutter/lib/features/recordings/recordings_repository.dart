import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/http/api_client.dart';
import '../../core/http/api_exception.dart';
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } finally {
      rawDio.close(force: true);
    }
  }

  /// `POST /api/recordings/{id}/process` (Bearer). Enqueues processing.
  /// Returns the (still-pending) recording echoed by the backend.
  Future<Recording> enqueueProcessing(int id) async {
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

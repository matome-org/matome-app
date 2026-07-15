import '../../core/http/json_utils.dart';
import 'recording.dart';

enum UploadMode { single, multipart }

enum UploadState { pending, uploading, uploaded, failed, aborted, stale }

/// A short-lived, unauthenticated storage request. Callers must never persist
/// [url] or its signed headers.
class UploadRequest {
  const UploadRequest({
    required this.method,
    required this.url,
    this.headers = const {},
  });

  factory UploadRequest.fromJson(Map<String, dynamic> json) => UploadRequest(
    method: asString(json['method'], fallback: 'PUT').toUpperCase(),
    url: asString(json['url']),
    headers: _stringMap(json['headers']),
  );

  final String method;
  final String url;
  final Map<String, String> headers;
}

/// Provider evidence for one accepted multipart part.
class UploadPart {
  const UploadPart({
    required this.partNumber,
    required this.etag,
    required this.checksumSha256,
    required this.byteSize,
  });

  factory UploadPart.fromJson(Map<String, dynamic> json) => UploadPart(
    partNumber: asIntOrNull(json['part_number']) ?? 0,
    etag: asString(json['etag']),
    checksumSha256: asString(json['checksum_sha256']),
    byteSize: asIntOrNull(json['byte_size']) ?? 0,
  );

  final int partNumber;
  final String etag;
  final String checksumSha256;
  final int byteSize;

  Map<String, dynamic> toCompleteJson() => <String, dynamic>{
    'part_number': partNumber,
    'etag': etag,
    'checksum_sha256': checksumSha256,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...toCompleteJson(),
    'byte_size': byteSize,
  };
}

class UploadPartDescriptor {
  const UploadPartDescriptor({
    required this.partNumber,
    required this.byteSize,
    required this.checksumSha256,
    required this.request,
  });

  factory UploadPartDescriptor.fromJson(Map<String, dynamic> json) {
    final request = json['request'];
    return UploadPartDescriptor(
      partNumber: asIntOrNull(json['part_number']) ?? 0,
      byteSize: asIntOrNull(json['byte_size']) ?? 0,
      checksumSha256: asString(json['checksum_sha256']),
      request: UploadRequest.fromJson(
        request is Map<String, dynamic> ? request : const <String, dynamic>{},
      ),
    );
  }

  final int partNumber;
  final int byteSize;
  final String checksumSha256;
  final UploadRequest request;
}

/// Core's owner-scoped single or multipart upload state.
class UploadDescriptor {
  const UploadDescriptor({
    required this.method,
    required this.url,
    required this.storageKey,
    this.headers = const {},
    this.expiresIn,
    this.uploadId = '',
    this.uploadGeneration = 1,
    this.mode = UploadMode.single,
    this.state = UploadState.pending,
    this.partSize,
    this.acceptedParts = const [],
    this.missingParts = const [],
    this.expiresAt,
    this.verifiedByteSize,
    this.verifiedChecksumSha256,
  });

  factory UploadDescriptor.fromJson(Map<String, dynamic> json) {
    final request = json['request'];
    final requestJson = request is Map<String, dynamic>
        ? request
        : const <String, dynamic>{};
    final accepted = json['accepted_parts'];
    final missing = json['missing_parts'];
    return UploadDescriptor(
      method: asString(requestJson['method'], fallback: 'PUT').toUpperCase(),
      url: asString(requestJson['url']),
      storageKey: asString(json['storage_key']),
      headers: _stringMap(requestJson['headers']),
      expiresIn: asIntOrNull(json['expires_in']),
      uploadId: asString(json['upload_id']),
      uploadGeneration: asIntOrNull(json['upload_generation']) ?? 1,
      mode: asString(json['mode']) == 'multipart'
          ? UploadMode.multipart
          : UploadMode.single,
      state: _uploadState(json['state']),
      partSize: asIntOrNull(json['part_size']),
      acceptedParts: accepted is List
          ? accepted
                .whereType<Map<String, dynamic>>()
                .map(UploadPart.fromJson)
                .toList(growable: false)
          : const [],
      missingParts: missing is List
          ? missing
                .whereType<num>()
                .map((value) => value.toInt())
                .toList(growable: false)
          : const [],
      expiresAt: asString(json['expires_at']).isEmpty
          ? null
          : asString(json['expires_at']),
      verifiedByteSize: asIntOrNull(json['verified_byte_size']),
      verifiedChecksumSha256: asString(json['verified_checksum_sha256']).isEmpty
          ? null
          : asString(json['verified_checksum_sha256']),
    );
  }

  final String method;
  final String url;
  final String storageKey;
  final Map<String, String> headers;
  final int? expiresIn;
  final String uploadId;
  final int uploadGeneration;
  final UploadMode mode;
  final UploadState state;
  final int? partSize;
  final List<UploadPart> acceptedParts;
  final List<int> missingParts;
  final String? expiresAt;
  final int? verifiedByteSize;
  final String? verifiedChecksumSha256;

  bool get isPost => method == 'POST';
  bool get isUploaded => state == UploadState.uploaded;

  UploadRequest? get request => url.isEmpty
      ? null
      : UploadRequest(method: method, url: url, headers: headers);
}

/// Combined response of `POST /api/matomes/{id}/items`.
class RecordingCreateResult {
  const RecordingCreateResult({required this.recording, required this.upload});

  final Recording recording;
  final UploadDescriptor upload;
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return <String, String>{
    for (final entry in value.entries)
      if (entry.key is String && entry.value != null)
        entry.key as String: entry.value.toString(),
  };
}

UploadState _uploadState(Object? value) => switch (value) {
  'uploading' => UploadState.uploading,
  'uploaded' => UploadState.uploaded,
  'failed' => UploadState.failed,
  'aborted' => UploadState.aborted,
  'stale' => UploadState.stale,
  _ => UploadState.pending,
};

import '../../core/http/json_utils.dart';
import 'recording.dart';

/// Presigned upload descriptor returned by `POST /api/recordings`.
///
/// Mirrors `MatomeApi.Storage.Presigner.presign_upload/2`:
///
/// ```elixir
/// %{method: "PUT", url: "...", storage_key: "...", expires_in: 900}
/// ```
///
/// The client PUTs (or POSTs, per [method]) the raw media bytes straight to
/// [url]; the URL embeds the AWS SigV4 signature so no extra auth header is
/// required (and must NOT be added — it would break the `host`-only signed
/// headers).
class UploadDescriptor {
  const UploadDescriptor({
    required this.method,
    required this.url,
    required this.storageKey,
    this.expiresIn,
  });

  /// `"PUT"` (default) or `"POST"`.
  final String method;
  final String url;
  final String storageKey;
  final int? expiresIn;

  bool get isPost => method.toUpperCase() == 'POST';

  factory UploadDescriptor.fromJson(Map<String, dynamic> json) {
    return UploadDescriptor(
      method: asString(json['method'], fallback: 'PUT').toUpperCase(),
      url: asString(json['url']),
      storageKey: asString(json['storage_key']),
      expiresIn: asIntOrNull(json['expires_in']),
    );
  }
}

/// Combined response of `POST /api/recordings`:
/// the created [recording] plus its presigned [upload] descriptor.
class RecordingCreateResult {
  const RecordingCreateResult({required this.recording, required this.upload});

  final Recording recording;
  final UploadDescriptor upload;
}

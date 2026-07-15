import '../../core/http/json_utils.dart';
import 'recording.dart';

/// Presigned request inside Core's W0 item-create `upload` envelope.
///
/// The wire shape is:
///
/// ```elixir
/// {upload: {request: {method: "PUT", url: "...", headers: {...}}}}
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
    final request = json['request'];
    final requestJson = request is Map<String, dynamic>
        ? request
        : const <String, dynamic>{};
    return UploadDescriptor(
      method: asString(requestJson['method'], fallback: 'PUT').toUpperCase(),
      url: asString(requestJson['url']),
      storageKey: '',
      expiresIn: asIntOrNull(json['expires_in']),
    );
  }
}

/// Combined response of `POST /api/matomes/{id}/items`:
/// the created [recording] plus its presigned [upload] descriptor.
class RecordingCreateResult {
  const RecordingCreateResult({required this.recording, required this.upload});

  final Recording recording;
  final UploadDescriptor upload;
}

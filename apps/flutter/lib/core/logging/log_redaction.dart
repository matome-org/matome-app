import 'package:logging/logging.dart';

const List<String> _sensitiveKeys = [
  'password',
  'code',
  'otp',
  'otp_code',
  'token',
  'ticket',
  'access_token',
  'refresh_token',
  'reset_token',
  'authorization',
  'auth',
  'secret',
  'client_secret',
  'api_key',
  'body',
  'content',
  'notes',
  'transcript',
  'summary',
  'local_path',
  'file_path',
  'path',
  'storage_url',
  'presigned_url',
  'x-amz-credential',
  'x-amz-signature',
  'x-amz-security-token',
  'awsaccesskeyid',
];

final RegExp _sensitiveFieldPattern = RegExp(
  '(["\']?(?:${_sensitiveKeys.map(RegExp.escape).join('|')})["\']?'
  r'''\s*(?:=|:)\s*)(?:"[^"]*"|'[^']*'|[^&,;\s}\]]+)''',
  caseSensitive: false,
);

final RegExp _bearerPattern = RegExp(
  r'\bBearer\s+[A-Za-z0-9._~+\/-]+=*',
  caseSensitive: false,
);

final RegExp _localPathPattern = RegExp(
  r'''(?:file://)?(?:/(?:home|Users|tmp)/[^\s"'&]+|[A-Za-z]:\\[^\s"'&]+)''',
);

/// Replaces the values of any sensitive query params in [message] with
/// `[REDACTED]`, leaving the rest of the message intact.
///
/// Matches `token=<value>` up to the next `&`, whitespace, quote, or end. This
/// is deliberately string-level (not URL-parse) so it also redacts the token
/// when it is embedded inside a larger log line such as
/// `Attempting to connect to wss://host/socket/websocket?vsn=2.0.0&token=ey...`.
String redactSensitiveQueryParams(String message) {
  return redactSensitiveLogData(message);
}

/// Redacts already-materialized log text without reading HTTP request bodies.
String redactSensitiveLogData(String message) {
  var out = message.replaceAll(_bearerPattern, 'Bearer [REDACTED]');
  out = out.replaceAllMapped(
    _sensitiveFieldPattern,
    (match) => '${match.group(1)}[REDACTED]',
  );
  return out.replaceAll(_localPathPattern, '[REDACTED_PATH]');
}

bool _installed = false;

/// Installs a root-logger listener that redacts sensitive query params (the
/// Guardian JWT in the phoenix_socket connect URL) from every emitted record.
///
/// CLIENT-side, BEST-EFFORT mitigation for the audit finding "token in WS URL
/// query" (#815): `phoenix_socket` logs `Attempting to connect to <mountPoint>`
/// at FINEST, and the mount point carries `?token=<jwt>`.
///
/// Scope and limits (do NOT treat this as a guarantee):
/// * It only redacts the message forwarded to THIS listener's [onRecord] sink.
///   It does NOT mutate the underlying `LogRecord`, so any OTHER
///   `Logger.root.onRecord.listen(...)` still sees the raw cleartext token.
/// * `Logger.root.level` defaults to `INFO`, so the FINEST socket record is
///   filtered out before publication today — redaction only actually fires if a
///   dev raises the level to FINE/ALL. The real fix is the short-TTL socket
///   ticket (backend follow-up; see the Security note in the migration report).
///
/// Idempotent — safe to call from `main()` once. Pass [onRecord] to forward the
/// already-redacted records to a real sink (e.g. a crash reporter); when null,
/// records are dropped after redaction (default app behaviour).
void installSocketLogRedaction({
  void Function(String message, LogRecord record)? onRecord,
}) {
  if (_installed) return;
  _installed = true;
  Logger.root.onRecord.listen((record) {
    final safe = redactSensitiveLogData(record.message);
    onRecord?.call(safe, record);
  });
}

import 'package:logging/logging.dart';

/// Query-param names whose values must never appear in app logs.
///
/// `token` is the Guardian access token (JWT) that `phoenix_socket` puts in the
/// WS connect URL (`?token=<jwt>`) per the Phoenix Socket contract; `ticket`
/// covers the planned short-TTL socket-ticket follow-up (see the Security note
/// in `.docs/flutter-migration-report.md`).
const List<String> _sensitiveQueryKeys = ['token', 'ticket'];

/// Replaces the values of any sensitive query params in [message] with
/// `[REDACTED]`, leaving the rest of the message intact.
///
/// Matches `token=<value>` up to the next `&`, whitespace, quote, or end. This
/// is deliberately string-level (not URL-parse) so it also redacts the token
/// when it is embedded inside a larger log line such as
/// `Attempting to connect to wss://host/socket/websocket?vsn=2.0.0&token=ey...`.
String redactSensitiveQueryParams(String message) {
  var out = message;
  for (final key in _sensitiveQueryKeys) {
    out = out.replaceAll(
      RegExp('$key=[^&\\s"\'\\]]+'),
      '$key=[REDACTED]',
    );
  }
  return out;
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
void installSocketLogRedaction({void Function(String message, LogRecord record)? onRecord}) {
  if (_installed) return;
  _installed = true;
  Logger.root.onRecord.listen((record) {
    final safe = redactSensitiveQueryParams(record.message);
    onRecord?.call(safe, record);
  });
}

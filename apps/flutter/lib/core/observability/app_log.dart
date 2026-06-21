import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path_provider/path_provider.dart';

import '../storage/app_storage.dart' show isRunningFlutterTest, kMatomeFolderName;

/// Coarse log categories so the single app log can be grepped per concern
/// (`grep ' sync:' app.log`, `grep '\[ERR\]'`, …).
enum LogCat {
  /// A caught failure that would otherwise be swallowed by a bare `catch`.
  error,

  /// Cloud sync push/pull lifecycle and reconcile counts.
  sync,

  /// A mutating user action (triage, contacts, spaces, recording lifecycle).
  action,

  /// Local→cloud upload queue lifecycle.
  upload,

  /// Auth lifecycle (login/logout/register/session/token refresh).
  auth,

  /// Database migrations, storage relocation, and other infra one-offs.
  db,

  /// App start and other process-lifecycle milestones.
  lifecycle,
}

/// Lightweight, dependency-free observability sink for the desktop/mobile app.
///
/// Writes one timestamped, categorised line per event to
/// `<documents>/Matome/app.log`, size-rotated at ~1 MB (previous file kept as
/// `app.log.1`). Best-effort and fully swallowed on failure — logging must never
/// break a user flow. No-op under `flutter test` (the path_provider channel
/// hangs there) and on web (no durable FS).
///
/// Use [error] for caught exceptions (ALWAYS written) and [event] for normal
/// lifecycle/action breadcrumbs (gated by [verbose], on by default).
class AppLog {
  AppLog._();

  /// Gates [event] (info) lines. Errors are always written regardless. Flip to
  /// `false` to silence the breadcrumbs while keeping error capture.
  static bool verbose = true;

  /// Rotation threshold in bytes. Overridable in tests so rotation can be
  /// exercised without writing a real megabyte.
  @visibleForTesting
  static int maxBytes = 1024 * 1024; // 1 MB

  /// Test seam: when set, each formatted line is delivered here synchronously
  /// instead of the file. Lets unit tests assert formatting / level routing /
  /// [verbose] gating / call-site redaction without the path_provider channel
  /// (which hangs under `flutter test`). Production leaves this null.
  @visibleForTesting
  static void Function(String line)? testSink;

  /// Serializes the fire-and-forget file writes. Each [_emit] chains its write
  /// behind the previous one so concurrent appends never interleave (the append
  /// race that corrupted lines when several logs fired in the same frame).
  static Future<void> _writeChain = Future<void>.value();

  /// Record a caught failure. ALWAYS written (ignores [verbose]).
  ///
  /// Fire-and-forget by design: never awaited, so logging can never introduce
  /// an async gap that changes a caller's timing, ordering, single-flight, or
  /// `mounted` lifecycle. The actual write runs detached.
  static void error(
    LogCat cat,
    String message, [
    Object? err,
    StackTrace? stack,
  ]) {
    final detail = err == null ? message : '$message — $err';
    _emit('ERR', cat, stack == null ? detail : '$detail\n$stack');
  }

  /// Record a normal breadcrumb (action/sync/lifecycle). Gated by [verbose].
  /// Fire-and-forget (see [error]).
  static void event(LogCat cat, String message) {
    if (!verbose) return;
    _emit('INF', cat, message);
  }

  /// Routes a formatted line to the test sink when present (synchronous), else
  /// to the detached file writer (production). Keeping this the single funnel
  /// means tests observe exactly what production would write.
  static void _emit(String level, LogCat cat, String message) {
    final sink = testSink;
    if (sink != null) {
      sink(formatLine(level, cat, message));
      return;
    }
    // Format NOW (call-time timestamp + ordering), then enqueue the write
    // behind any in-flight one. Serializing avoids the concurrent-append race
    // that interleaved and corrupted lines. A failed write must not break the
    // chain, so swallow per-write errors here.
    final line = formatLine(level, cat, message);
    _writeChain = _writeChain.then((_) => _writeRaw(line)).catchError((_) {});
  }

  /// The exact on-disk line shape (sans trailing newline). Pure: same inputs →
  /// same string (modulo the timestamp), so it is unit-testable.
  @visibleForTesting
  static String formatLine(String level, LogCat cat, String message) =>
      '${DateTime.now().toIso8601String()} [$level] ${cat.name}: $message';

  static Future<void> _writeRaw(String line) async {
    if (isRunningFlutterTest || kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      await writeLineTo(docs, line);
    } catch (_) {
      // Observability must never throw into a caller.
    }
  }

  /// Appends [line] to `<baseDir>/Matome/app.log`, rotating to `app.log.1`
  /// first when the file already exceeds [maxBytes]. Exposed for tests so the
  /// rotation path can run against a real temp dir (production routes here via
  /// [getApplicationDocumentsDirectory]).
  @visibleForTesting
  static Future<void> writeLineTo(Directory baseDir, String line) async {
    final f = File('${baseDir.path}/$kMatomeFolderName/app.log');
    await f.parent.create(recursive: true);
    if (await f.exists() && await f.length() > maxBytes) {
      try {
        await f.rename('${f.path}.1'); // keep one previous file
      } catch (_) {}
    }
    await f.writeAsString('$line\n', mode: FileMode.append);
  }
}

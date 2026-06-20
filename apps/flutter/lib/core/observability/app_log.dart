import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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

  static const int _maxBytes = 1024 * 1024; // 1 MB

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
    unawaited(_write('ERR', cat, stack == null ? detail : '$detail\n$stack'));
  }

  /// Record a normal breadcrumb (action/sync/lifecycle). Gated by [verbose].
  /// Fire-and-forget (see [error]).
  static void event(LogCat cat, String message) {
    if (!verbose) return;
    unawaited(_write('INF', cat, message));
  }

  static Future<void> _write(String level, LogCat cat, String message) async {
    if (isRunningFlutterTest || kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final f = File('${docs.path}/$kMatomeFolderName/app.log');
      await f.parent.create(recursive: true);
      if (await f.exists() && await f.length() > _maxBytes) {
        try {
          await f.rename('${f.path}.1'); // keep one previous file
        } catch (_) {}
      }
      await f.writeAsString(
        '${DateTime.now().toIso8601String()} [$level] ${cat.name}: $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Observability must never throw into a caller.
    }
  }
}

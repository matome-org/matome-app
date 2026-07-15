import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/endpoint_controller.dart';
import '../../core/observability/app_log.dart';
import 'upload_queue.dart';

/// A reachability check for Core — returns `true` when the supplied runtime URL
/// answers. Injectable so tests drive connectivity transitions with a fake
/// instead of a live socket. The default ([probeApiReachability]) issues a
/// cheap GET to the API root and treats *any* HTTP reply (even 4xx) as
/// reachable — only a transport error (no statusCode) means "offline".
typedef ReachabilityProbe = Future<bool> Function(String baseUrl);

/// Default [ReachabilityProbe]: a short-timeout GET to the runtime endpoint.
/// Any HTTP response (incl. 404/401) ⇒ reachable; a connection/timeout error ⇒
/// unreachable. Uses a bare [Dio] (no auth) so it works pre-login too.
Future<bool> probeApiReachability(String baseUrl) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      validateStatus: (_) => true,
    ),
  );
  try {
    final res = await dio.get<void>('/');
    return res.statusCode != null;
  } catch (e, st) {
    AppLog.error(
      LogCat.upload,
      'probeApiReachability: probe failed (treated as offline)',
      e,
      st,
    );
    return false;
  } finally {
    dio.close(force: true);
  }
}

/// Drives the [UploadQueue] on production recovery triggers:
///  (a) app start — drain once immediately,
///  (b) connectivity/due retry — a lightweight periodic reachability probe to
///      the current [endpointConfigProvider] drains while reachable, with the
///      durable queue's `available_at` enforcing backoff,
///  (c) auth success, foreground/resume, and endpoint changes — wired by the
///      app root through [drainNow],
///  (d) after a finish() — handled in-line by `InboxUploader.upload`'s drain.
///
/// No `connectivity_plus` dependency exists in the project, so this uses a
/// simple injectable HTTP reachability probe rather than pulling in a native
/// connectivity plugin — keeps the lab build dependency-light and fully
/// testable with a fake probe (no real socket).
class UploadRetryService {
  UploadRetryService(
    this._ref, {
    this.probe = probeApiReachability,
    this.interval = const Duration(seconds: 30),
  });

  final Ref _ref;

  /// Core reachability check. Injectable so tests drive connectivity edges.
  final ReachabilityProbe probe;

  /// How often reachability is re-probed for the connectivity-regained trigger.
  final Duration interval;

  Timer? _timer;
  bool _lastReachable = false;
  bool _started = false;

  UploadQueue get _queue => _ref.read(uploadQueueProvider);

  /// Start the service: drain once, then poll reachability and let due durable
  /// retries advance while Core remains reachable. Idempotent.
  Future<void> start() async {
    if (_started) return;
    AppLog.event(LogCat.upload, 'start: retry service starting');
    _started = true;

    // (a) App-start drain — clears any backlog left by a previous session that
    //     died with Core unreachable. Best-effort: the queue never throws.
    unawaited(_queue.drain());

    // Seed the reachability edge detector so we don't double-drain on the first
    // tick if Core was already up at start.
    _lastReachable = await _safeProbe();

    // (b) Connectivity + due-retry trigger. The queue itself rejects work whose
    //     available_at is still in the future, so steady reachability does not
    //     bypass exponential backoff.
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    final reachable = await _safeProbe();
    final regained = reachable && !_lastReachable;
    _lastReachable = reachable;
    if (reachable) {
      AppLog.event(
        LogCat.upload,
        regained
            ? '_tick: connectivity regained, draining'
            : '_tick: reachable, draining due work',
      );
      unawaited(_queue.drain());
    }
  }

  /// Manually nudge a drain (used by triggers that already know Core is up,
  /// e.g. a successful foreground sync). Best-effort.
  Future<void> drainNow() {
    AppLog.event(LogCat.upload, 'drainNow: manual drain');
    return _queue.drain();
  }

  Future<bool> _safeProbe() async {
    try {
      return await probe(_ref.read(endpointConfigProvider));
    } catch (e, st) {
      AppLog.error(
        LogCat.upload,
        '_safeProbe: reachability probe threw',
        e,
        st,
      );
      developer.log('reachability probe threw', name: 'upload.retry', error: e);
      return false;
    }
  }

  /// Stop polling and release the timer. Idempotent.
  void dispose() {
    AppLog.event(LogCat.upload, 'dispose: retry service stopped');
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}

final uploadRetryServiceProvider = Provider<UploadRetryService>((ref) {
  final service = UploadRetryService(ref);
  ref.onDispose(service.dispose);
  return service;
});

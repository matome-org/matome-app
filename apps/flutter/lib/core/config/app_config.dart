import 'package:flutter/foundation.dart';

/// Runtime configuration for the Flutter lab client.
///
/// The Phoenix Core API base URL is resolved per-platform so the same build
/// talks to the right host:
///
/// * Web & Linux desktop  -> `http://localhost:7001` (the dev API is local).
/// * Android emulator     -> `http://10.0.2.2:7001` (the emulator's alias for
///   the host loopback). If you prefer `adb reverse tcp:7001 tcp:7001`, pass
///   `--dart-define=API_BASE_URL=http://localhost:7001` to override.
/// * Everything else      -> falls back to `http://localhost:7001`.
///
/// An explicit `--dart-define=API_BASE_URL=...` always wins, so CI / device
/// testing can point at any host without code changes.
class AppConfig {
  const AppConfig._();

  /// Compile-time override. Empty when not provided.
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _localBaseUrl = 'http://localhost:7001';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:7001';

  /// Resolves the API base URL for the current platform.
  static String get apiBaseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    return resolveBaseUrl(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      override: _overrideBaseUrl,
    );
  }

  /// Pure resolver, exposed for testing.
  @visibleForTesting
  static String resolveBaseUrl({
    required bool isWeb,
    required TargetPlatform platform,
    String override = '',
  }) {
    if (override.isNotEmpty) return override;
    if (isWeb) return _localBaseUrl;
    if (platform == TargetPlatform.android) return _androidEmulatorBaseUrl;
    return _localBaseUrl;
  }
}

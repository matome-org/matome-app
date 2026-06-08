import 'package:flutter/foundation.dart';

/// Runtime configuration for the Flutter lab client.
///
/// The Phoenix Core API base URL is resolved per-platform so the same build
/// talks to the right host:
///
/// * Web & Linux desktop  -> `http://localhost:4000` (the dev API is local).
/// * Android emulator     -> `http://10.0.2.2:4000` (the emulator's alias for
///   the host loopback). If you prefer `adb reverse tcp:4000 tcp:4000`, pass
///   `--dart-define=API_BASE_URL=http://localhost:4000` to override.
/// * Everything else      -> falls back to `http://localhost:4000`.
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

  static const String _localBaseUrl = 'http://localhost:4000';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:4000';

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

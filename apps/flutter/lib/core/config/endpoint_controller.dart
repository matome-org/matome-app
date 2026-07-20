import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/settings_store.dart';
import 'app_config.dart';

/// Secure-storage key holding the god-mode backend base-URL override. Empty /
/// absent means "use the platform default" ([AppConfig.apiBaseUrl]).
const String kApiBaseUrlOverrideKey = 'matome.god_mode.api_base_url';

/// Holds the *effective* Core API base URL and, under god mode, lets the user
/// point the whole client at a custom host (Bitwarden-style self-host).
///
/// The state is the effective base URL, seeded synchronously with the platform
/// default so [apiClientProvider] can build immediately, then reconciled with
/// the persisted override once secure storage resolves (mirrors
/// [ThemeController]'s hydrate-then-update pattern). When the override changes,
/// [apiClientProvider] rebuilds the [ApiClient] (and every repo watching it),
/// so the new host takes effect without a restart.
///
/// This controller owns ONLY the URL. Switching hosts invalidates the old
/// host's session, but clearing tokens / signing out is the caller's job — the
/// UI action calls [setBaseUrl] and then drops the session, keeping this class
/// free of an auth dependency.
class EndpointController extends StateNotifier<String> {
  EndpointController(this._store) : super(AppConfig.apiBaseUrl) {
    _hydrate();
  }

  final SettingsStore _store;

  /// The compile-time platform default, i.e. the value used when no override is
  /// set. Exposed so the UI can show "(default)" and offer a reset.
  String get defaultBaseUrl => AppConfig.apiBaseUrl;

  /// True when a custom host override is active (differs from the default).
  bool get isOverridden => state != defaultBaseUrl;

  Future<void> _hydrate() async {
    // Best-effort: a secure-storage read can throw (no plugin in unit tests, a
    // locked keystore on device). Any failure just keeps the platform default —
    // it must never surface as an unhandled async error, since this controller
    // is constructed eagerly by [apiClientProvider] on nearly every screen/test.
    try {
      final raw = normalizeBaseUrl(await _store.read(kApiBaseUrlOverrideKey));
      if (raw != null && mounted) state = raw;
    } catch (_) {
      // Ignore — fall back to AppConfig.apiBaseUrl.
    }
  }

  /// Persist and apply a custom base URL. Returns `true` when [url] is a valid
  /// absolute http(s) URL and was applied; `false` (no-op) when malformed, so
  /// the caller can surface a validation error.
  Future<bool> setBaseUrl(String url) async {
    final normalized = normalizeBaseUrl(url);
    if (normalized == null) return false;
    state = normalized;
    await _store.write(kApiBaseUrlOverrideKey, normalized);
    return true;
  }

  /// Clear the override and fall back to the platform default.
  Future<void> reset() async {
    state = defaultBaseUrl;
    await _store.write(kApiBaseUrlOverrideKey, '');
  }

  /// Trim, drop a trailing slash, and validate as an absolute http(s) URL with
  /// a host. Returns the cleaned URL, or `null` when empty/malformed.
  static String? normalizeBaseUrl(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return value;
  }
}

/// The effective Core API base URL. [apiClientProvider] watches this.
final endpointConfigProvider =
    StateNotifierProvider<EndpointController, String>(
      (ref) => EndpointController(ref.watch(settingsStoreProvider)),
    );

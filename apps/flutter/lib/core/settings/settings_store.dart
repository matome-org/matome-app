import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists small app-level UI preferences (theme mode, language) as plain
/// string key/value pairs.
///
/// Mirrors the RN `themeStore` / `languageStore` (zustand + expo-secure-store)
/// persistence by reusing the same `flutter_secure_storage` backend already
/// wired for the auth tokens. Abstracted so widget tests can swap in an
/// in-memory implementation without the platform channel.
abstract class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Default [SettingsStore] backed by `flutter_secure_storage`.
class SecureSettingsStore implements SettingsStore {
  SecureSettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// In-memory [SettingsStore] for tests and platforms without secure storage.
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

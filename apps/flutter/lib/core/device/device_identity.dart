import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Client-declared device descriptor sent on login/register (`device` body).
class DeviceDescriptor {
  const DeviceDescriptor({
    required this.id,
    required this.platform,
    required this.formFactor,
    required this.deviceClass,
    this.model,
    required this.displayName,
  });

  final String id;
  final String platform;
  final String formFactor;
  final String deviceClass;
  final String? model;
  final String displayName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform': platform,
    'form_factor': formFactor,
    'device_class': deviceClass,
    if (model != null && model!.isNotEmpty) 'model': model,
    'display_name': displayName,
  };
}

/// Resolves the stable device identity for auth session metadata.
abstract class DeviceIdentity {
  Future<DeviceDescriptor> current();
}

/// Fixed descriptor for tests / injection.
class FixedDeviceIdentity implements DeviceIdentity {
  FixedDeviceIdentity(this.descriptor);

  final DeviceDescriptor descriptor;

  @override
  Future<DeviceDescriptor> current() async => descriptor;
}

/// Persists the install-scoped client device UUID.
abstract class DeviceClientIdStore {
  Future<String?> read();
  Future<void> write(String id);
}

/// Default [DeviceClientIdStore] backed by `flutter_secure_storage`.
class SecureDeviceClientIdStore implements DeviceClientIdStore {
  SecureDeviceClientIdStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _idKey = 'matome.device_client_id';

  @override
  Future<String?> read() => _storage.read(key: _idKey);

  @override
  Future<void> write(String id) => _storage.write(key: _idKey, value: id);
}

/// In-memory store for unit tests.
class InMemoryDeviceClientIdStore implements DeviceClientIdStore {
  String? _id;

  @override
  Future<String?> read() async => _id;

  @override
  Future<void> write(String id) async => _id = id;
}

/// Production identity: stable UUID + platform mapping + optional model.
class SecureDeviceIdentity implements DeviceIdentity {
  factory SecureDeviceIdentity({
    DeviceClientIdStore? clientIdStore,
    String Function()? idGenerator,
    Future<String?> Function()? modelResolver,
    bool? isWeb,
    TargetPlatform? platform,
  }) {
    return SecureDeviceIdentity._(
      clientIdStore ?? SecureDeviceClientIdStore(),
      idGenerator ?? const Uuid().v4,
      modelResolver,
      isWeb ?? kIsWeb,
      platform ?? defaultTargetPlatform,
    );
  }

  SecureDeviceIdentity._(
    this._clientIdStore,
    this._idGenerator,
    this._modelResolver,
    this._isWeb,
    this._platform,
  );

  final DeviceClientIdStore _clientIdStore;
  final String Function() _idGenerator;
  final Future<String?> Function()? _modelResolver;
  final bool _isWeb;
  final TargetPlatform _platform;

  @override
  Future<DeviceDescriptor> current() async {
    final id = await _stableId();
    final mapped = mapPlatform(isWeb: _isWeb, platform: _platform);
    String? model;
    try {
      model = await _modelResolver?.call();
    } catch (_) {
      model = null;
    }
    final trimmedModel = model?.trim();
    final displayName = (trimmedModel != null && trimmedModel.isNotEmpty)
        ? trimmedModel
        : mapped.defaultDisplayName;

    return DeviceDescriptor(
      id: id,
      platform: mapped.platform,
      formFactor: mapped.formFactor,
      deviceClass: mapped.deviceClass,
      model: (trimmedModel != null && trimmedModel.isNotEmpty)
          ? trimmedModel
          : null,
      displayName: displayName,
    );
  }

  Future<String> _stableId() async {
    final existing = await _clientIdStore.read();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _idGenerator();
    await _clientIdStore.write(created);
    return created;
  }
}

/// Pure platform → contract mapping (unit-testable without plugins).
({
  String platform,
  String formFactor,
  String deviceClass,
  String defaultDisplayName,
})
mapPlatform({required bool isWeb, required TargetPlatform platform}) {
  if (isWeb) {
    return (
      platform: 'web',
      formFactor: 'web',
      deviceClass: 'browser',
      defaultDisplayName: 'Browser',
    );
  }

  return switch (platform) {
    TargetPlatform.android => (
      platform: 'android',
      formFactor: 'mobile',
      deviceClass: 'smartphone',
      defaultDisplayName: 'Android device',
    ),
    TargetPlatform.iOS => (
      platform: 'ios',
      formFactor: 'mobile',
      deviceClass: 'smartphone',
      defaultDisplayName: 'iPhone',
    ),
    TargetPlatform.macOS => (
      platform: 'macos',
      formFactor: 'desktop',
      deviceClass: 'desktop',
      defaultDisplayName: 'Mac',
    ),
    TargetPlatform.windows => (
      platform: 'windows',
      formFactor: 'desktop',
      deviceClass: 'desktop',
      defaultDisplayName: 'Windows PC',
    ),
    TargetPlatform.linux => (
      platform: 'linux',
      formFactor: 'desktop',
      deviceClass: 'desktop',
      defaultDisplayName: 'Linux PC',
    ),
    TargetPlatform.fuchsia => (
      platform: 'unknown',
      formFactor: 'unknown',
      deviceClass: 'unknown',
      defaultDisplayName: 'Device',
    ),
  };
}

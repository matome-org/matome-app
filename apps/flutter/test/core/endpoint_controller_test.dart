import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/config/app_config.dart';
import 'package:matome_flutter/core/config/endpoint_controller.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';

/// A store whose read throws — mirrors the MissingPluginException / locked
/// keystore case that must not crash the eager hydrate.
class _ThrowingSettingsStore implements SettingsStore {
  @override
  Future<String?> read(String key) async => throw StateError('storage down');
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('storage down');
}

void main() {
  group('EndpointController.normalizeBaseUrl', () {
    test('trims and strips trailing slashes', () {
      expect(
        EndpointController.normalizeBaseUrl('  https://api.example.com/  '),
        'https://api.example.com',
      );
      expect(
        EndpointController.normalizeBaseUrl('http://10.0.0.5:7001//'),
        'http://10.0.0.5:7001',
      );
    });

    test('rejects empty, null, and non-http(s) URLs', () {
      expect(EndpointController.normalizeBaseUrl(null), isNull);
      expect(EndpointController.normalizeBaseUrl('   '), isNull);
      expect(EndpointController.normalizeBaseUrl('not a url'), isNull);
      expect(EndpointController.normalizeBaseUrl('ftp://host'), isNull);
      expect(EndpointController.normalizeBaseUrl('https://'), isNull);
    });
  });

  group('EndpointController', () {
    test('defaults to the platform base URL when no override persisted', () {
      final c = EndpointController(InMemorySettingsStore());
      expect(c.state, AppConfig.apiBaseUrl);
      expect(c.isOverridden, isFalse);
    });

    test('hydrates a persisted override', () async {
      final store = InMemorySettingsStore({
        kApiBaseUrlOverrideKey: 'https://staging.example.com',
      });
      final c = EndpointController(store);
      // hydrate is async; pump the microtask queue.
      await Future<void>.delayed(Duration.zero);
      expect(c.state, 'https://staging.example.com');
      expect(c.isOverridden, isTrue);
    });

    test(
      'setBaseUrl applies + persists a valid host, rejects a bad one',
      () async {
        final store = InMemorySettingsStore();
        final c = EndpointController(store);

        expect(await c.setBaseUrl('http://192.168.1.9:7001/'), isTrue);
        expect(c.state, 'http://192.168.1.9:7001');
        expect(
          await store.read(kApiBaseUrlOverrideKey),
          'http://192.168.1.9:7001',
        );
        expect(c.isOverridden, isTrue);

        final before = c.state;
        expect(await c.setBaseUrl('garbage'), isFalse);
        expect(c.state, before, reason: 'invalid input must be a no-op');
      },
    );

    test(
      'tolerates a throwing store on hydrate (keeps default, no crash)',
      () async {
        final c = EndpointController(_ThrowingSettingsStore());
        // The eager hydrate must swallow the storage error.
        await Future<void>.delayed(Duration.zero);
        expect(c.state, c.defaultBaseUrl);
        expect(c.isOverridden, isFalse);
      },
    );

    test('reset falls back to the default and clears the override', () async {
      final store = InMemorySettingsStore();
      final c = EndpointController(store);
      await c.setBaseUrl('https://custom.example.com');
      expect(c.isOverridden, isTrue);

      await c.reset();
      expect(c.state, c.defaultBaseUrl);
      expect(c.isOverridden, isFalse);
      expect(await store.read(kApiBaseUrlOverrideKey), '');
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/device/device_identity.dart';

void main() {
  group('mapPlatform', () {
    test('web', () {
      final m = mapPlatform(isWeb: true, platform: TargetPlatform.linux);
      expect(m.platform, 'web');
      expect(m.formFactor, 'web');
      expect(m.deviceClass, 'browser');
    });

    test('android', () {
      final m = mapPlatform(isWeb: false, platform: TargetPlatform.android);
      expect(m.platform, 'android');
      expect(m.formFactor, 'mobile');
      expect(m.deviceClass, 'smartphone');
    });

    test('ios', () {
      final m = mapPlatform(isWeb: false, platform: TargetPlatform.iOS);
      expect(m.platform, 'ios');
      expect(m.formFactor, 'mobile');
      expect(m.deviceClass, 'smartphone');
    });

    test('linux desktop', () {
      final m = mapPlatform(isWeb: false, platform: TargetPlatform.linux);
      expect(m.platform, 'linux');
      expect(m.formFactor, 'desktop');
      expect(m.deviceClass, 'desktop');
    });

    test('windows desktop', () {
      final m = mapPlatform(isWeb: false, platform: TargetPlatform.windows);
      expect(m.platform, 'windows');
      expect(m.formFactor, 'desktop');
      expect(m.deviceClass, 'desktop');
    });

    test('macos desktop', () {
      final m = mapPlatform(isWeb: false, platform: TargetPlatform.macOS);
      expect(m.platform, 'macos');
      expect(m.formFactor, 'desktop');
      expect(m.deviceClass, 'desktop');
    });
  });

  group('SecureDeviceIdentity', () {
    test('persists a stable id and prefers model for display_name', () async {
      final store = InMemoryDeviceClientIdStore();
      final identity = SecureDeviceIdentity(
        clientIdStore: store,
        isWeb: false,
        platform: TargetPlatform.linux,
        modelResolver: () async => 'ThinkPad T14',
        idGenerator: () => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      );

      final first = await identity.current();
      final second = await identity.current();

      expect(first.id, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(second.id, first.id);
      expect(first.platform, 'linux');
      expect(first.formFactor, 'desktop');
      expect(first.deviceClass, 'desktop');
      expect(first.model, 'ThinkPad T14');
      expect(first.displayName, 'ThinkPad T14');
      expect(first.toJson()['form_factor'], 'desktop');
    });
  });
}

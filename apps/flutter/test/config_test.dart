import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig.resolveBaseUrl', () {
    test('web -> localhost', () {
      expect(
        AppConfig.resolveBaseUrl(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'http://localhost:4000',
      );
    });

    test('android emulator -> 10.0.2.2', () {
      expect(
        AppConfig.resolveBaseUrl(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'http://10.0.2.2:4000',
      );
    });

    test('linux desktop -> localhost', () {
      expect(
        AppConfig.resolveBaseUrl(
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        'http://localhost:4000',
      );
    });

    test('explicit override wins on every platform', () {
      expect(
        AppConfig.resolveBaseUrl(
          isWeb: false,
          platform: TargetPlatform.android,
          override: 'http://example.test:9000',
        ),
        'http://example.test:9000',
      );
    });
  });
}

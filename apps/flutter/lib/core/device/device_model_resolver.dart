import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Best-effort hardware / hostname label for [SecureDeviceIdentity].
///
/// Returns null when the plugin is unavailable (tests, unsupported host).
Future<String?> resolveDeviceModel() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final info = await plugin.webBrowserInfo;
      final browser = info.browserName.name;
      if (browser.isEmpty || browser == 'unknown') return 'Browser';
      return browser[0].toUpperCase() + browser.substring(1);
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => (await plugin.androidInfo).model,
      TargetPlatform.iOS => (await plugin.iosInfo).utsname.machine,
      TargetPlatform.linux => (await plugin.linuxInfo).prettyName,
      TargetPlatform.macOS => (await plugin.macOsInfo).computerName,
      TargetPlatform.windows => (await plugin.windowsInfo).computerName,
      TargetPlatform.fuchsia => null,
    };
  } catch (_) {
    return null;
  }
}

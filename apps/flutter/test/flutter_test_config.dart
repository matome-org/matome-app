import 'dart:async';

import 'package:alchemist/alchemist.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(
        platforms: {HostPlatform.linux},
        obscureText: true,
        renderShadows: false,
        filePathResolver: _goldenFilePath,
      ),
      ciGoldensConfig: const CiGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}

String _goldenFilePath(String fileName, String environmentName) {
  return '${environmentName.toLowerCase()}/$fileName.png';
}

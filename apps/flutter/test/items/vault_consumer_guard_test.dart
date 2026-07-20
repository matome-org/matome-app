import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media and delete features do not regain durable path APIs', () {
    final roots = [Directory('lib/features'), Directory('lib/core/vault')];
    final recorderStagingAllowlist = {
      'lib/features/recording/meeting_capture_service.dart',
    };
    final violations = <String>[];
    final banned = <String, RegExp>{
      'Image.file': RegExp(r'\bImage\.file\s*\('),
      'Uri.file': RegExp(r'\bUri\.file\s*\('),
      'File.lengthSync': RegExp(r'\blengthSync\s*\('),
      'direct payload delete': RegExp(r'\.deleteWithPayload\s*\('),
      'durable media path field': RegExp(r'\b(?:localPath|sourcePath)\b'),
      'retired playback resolver': RegExp(r'media_playback_resolver'),
    };

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final entry in banned.entries) {
          if (entry.value.hasMatch(source)) {
            if (entry.key == 'durable media path field' &&
                recorderStagingAllowlist.contains(entity.path)) {
              continue;
            }
            violations.add('${entity.path}: ${entry.key}');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

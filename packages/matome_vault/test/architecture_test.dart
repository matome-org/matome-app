import 'dart:io';

import 'package:test/test.dart';

final _forbiddenImports = <RegExp>[
  RegExp(r'''(?:import|export)\s+['"]dart:ffi['"]'''),
  RegExp(r'''(?:import|export)\s+['"]package:flutter(?:/|['"])'''),
  RegExp(r'''(?:import|export)\s+['"]package:flutter_riverpod(?:/|['"])'''),
  RegExp(r'''(?:import|export)\s+['"]package:riverpod(?:/|['"])'''),
  RegExp(r'''(?:import|export)\s+['"]package:drift(?:/|['"])'''),
  RegExp(r'''(?:import|export)\s+['"]package:matome_flutter(?:/|['"])'''),
  RegExp(r'''(?:import|export)\s+['"][^'"]*apps/flutter'''),
  RegExp(r'''(?:import|export)\s+['"][^'"]*(?:repositories|endpoints)/'''),
];

List<String> _violations(String source) => _forbiddenImports
    .where((pattern) => pattern.hasMatch(source))
    .map((pattern) => pattern.pattern)
    .toList();

void main() {
  test('public package source stays Dart-only and app-independent', () {
    final lib = Directory('lib');
    final sources = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final violations = <String>[];
    for (final source in sources) {
      final contents = source.readAsStringSync();
      if (source.path.endsWith('native_blob_store_io.dart')) {
        expect(contents, contains("import 'dart:io';"));
      } else if (RegExp(
        r'''(?:import|export)\s+['"]dart:io['"]''',
      ).hasMatch(contents)) {
        violations.add('${source.path}: dart:io outside conditional backend');
      }
      for (final pattern in _violations(contents)) {
        violations.add('${source.path}: $pattern');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('guard detects every prohibited dependency family', () {
    const prohibitedExamples = [
      "import 'dart:ffi';",
      "import 'package:flutter/widgets.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      "import 'package:riverpod/riverpod.dart';",
      "import 'package:drift/drift.dart';",
      "import 'package:matome_flutter/core/providers.dart';",
      "import '../../../apps/flutter/lib/core/providers.dart';",
      "import '../repositories/media_repository.dart';",
      "export '../endpoints/core.dart';",
    ];

    for (final source in prohibitedExamples) {
      expect(_violations(source), isNotEmpty, reason: source);
    }
  });
}

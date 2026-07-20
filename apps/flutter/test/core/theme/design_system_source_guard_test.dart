import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design-system source guard', () {
    test('Flutter lib source only contains reviewed visual primitives', () {
      final guard = _DesignSystemSourceGuard();
      final result = guard.evaluate(_loadFlutterLibSources(), _baseline);

      expect(result.failureMessage, isNull, reason: result.failureMessage);
    });

    test('new hardcoded feature colors are caught', () {
      final guard = _DesignSystemSourceGuard();
      final violations = guard.scan(const [
        _SourceFile(
          path: 'lib/features/example/example_screen.dart',
          content: '''
import 'package:flutter/material.dart';

class ExampleScreen {
  final badAccent = Color(0xFF00FF00);
}
''',
        ),
      ]);

      expect(
        violations.map((violation) => violation.ruleId),
        contains('ds.color.literal'),
      );
    });

    test('new hardcoded visual size literals are caught', () {
      final guard = _DesignSystemSourceGuard();
      final violations = guard.scan(const [
        _SourceFile(
          path: 'lib/features/example/example_screen.dart',
          content: '''
import 'package:flutter/material.dart';

class ExampleScreen {
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(width: 44, height: 44),
        const ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 320),
          child: SizedBox.shrink(),
        ),
        const Icon(Icons.add, size: 20),
        const LoadingIndicator(size: 18, strokeWidth: 2),
      ],
    );
  }
}
''',
        ),
      ]);

      final sizeViolations = violations
          .where((violation) => violation.ruleId == 'ds.size.inline')
          .toList();

      expect(sizeViolations, hasLength(5));
      expect(
        sizeViolations.map((violation) => violation.snippet),
        containsAll(<String>[
          'const SizedBox(height: 24),',
          'Container(width: 44, height: 44),',
          'constraints: BoxConstraints(maxWidth: 320),',
          'const Icon(Icons.add, size: 20),',
          'const LoadingIndicator(size: 18, strokeWidth: 2),',
        ]),
      );
    });
  });
}

final List<_BaselineEntry> _baseline = const [];

List<_SourceFile> _loadFlutterLibSources() {
  final lib = Directory('lib');
  expect(lib.existsSync(), isTrue, reason: 'Run this test from apps/flutter.');

  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => _isScannedSource(_relativePath(file)))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  return files
      .map(
        (file) => _SourceFile(
          path: _relativePath(file),
          content: file.readAsStringSync(),
        ),
      )
      .toList();
}

String _relativePath(File file) => file.path.replaceAll('\\', '/');

bool _isScannedSource(String path) {
  if (!path.startsWith('lib/') || !path.endsWith('.dart')) return false;
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return false;
  if (path.endsWith('.mocks.dart') || path.endsWith('.mock.dart')) return false;
  if (path.contains('/generated/') || path.contains('/fixtures/')) return false;
  return true;
}

final class _DesignSystemSourceGuard {
  List<_Violation> scan(List<_SourceFile> files) {
    final violations = <_Violation>[];

    for (final file in files) {
      final lines = file.content.split('\n');
      for (var index = 0; index < lines.length; index += 1) {
        final line = _withoutLineComment(lines[index]);
        if (line.trim().isEmpty) continue;

        if (_disallowsAppVisualPrimitives(file.path)) {
          _scanHardcodedColors(file, lines, index, violations);
          _scanInlineTextStyle(file, lines, index, violations);
          _scanSpacingRadiusElevation(file, lines, index, violations);
          _scanVisualSizeLiterals(file, lines, index, violations);
          _scanDirectMaterialPrimitive(file, line, index, violations);
        }

        _scanThemeExtensionFallback(file, line, index, violations);
      }
    }

    return violations;
  }

  _GuardResult evaluate(
    List<_SourceFile> files,
    List<_BaselineEntry> baseline,
  ) {
    final violations = scan(files);
    final baselineKeys = <String, _BaselineEntry>{};
    final duplicateBaseline = <_BaselineEntry>[];
    final invalidBaseline = <_BaselineEntry>[];
    final expiredBaseline = <_BaselineEntry>[];

    for (final entry in baseline) {
      if (!entry.isWellFormed) invalidBaseline.add(entry);
      if (entry.isExpired) expiredBaseline.add(entry);

      final key = entry.key;
      if (baselineKeys.containsKey(key)) {
        duplicateBaseline.add(entry);
      } else {
        baselineKeys[key] = entry;
      }
    }

    final reviewed = <String>{};
    final unreviewed = <_Violation>[];

    for (final violation in violations) {
      final key = violation.key;
      final entry = baselineKeys[key];
      if (entry == null || entry.isExpired) {
        unreviewed.add(violation);
      } else {
        reviewed.add(key);
      }
    }

    final staleBaseline = baseline
        .where((entry) => !entry.isExpired && !reviewed.contains(entry.key))
        .toList();

    return _GuardResult(
      violations: violations,
      unreviewedViolations: unreviewed,
      staleBaseline: staleBaseline,
      invalidBaseline: invalidBaseline,
      duplicateBaseline: duplicateBaseline,
      expiredBaseline: expiredBaseline,
    );
  }

  void _scanHardcodedColors(
    _SourceFile file,
    List<String> lines,
    int index,
    List<_Violation> violations,
  ) {
    final line = _withoutLineComment(lines[index]);
    final colorWindow = [
      line,
      if (index + 1 < lines.length) _withoutLineComment(lines[index + 1]),
      if (index + 2 < lines.length) _withoutLineComment(lines[index + 2]),
    ].join(' ');

    if (_hardcodedColorPattern.hasMatch(colorWindow)) {
      violations.add(
        _violation(
          ruleId: 'ds.color.literal',
          path: file.path,
          line: index + 1,
          snippet: lines[index],
          remediation:
              'Move color values into MatomeColors or use context.colors.',
        ),
      );
    }

    if (_materialColorPattern.hasMatch(line)) {
      violations.add(
        _violation(
          ruleId: 'ds.color.material',
          path: file.path,
          line: index + 1,
          snippet: lines[index],
          remediation:
              'Use MatomeColors/context.colors instead of Material Colors.*.',
        ),
      );
    }
  }

  void _scanInlineTextStyle(
    _SourceFile file,
    List<String> lines,
    int index,
    List<_Violation> violations,
  ) {
    if (!_textStyleStartPattern.hasMatch(lines[index])) return;

    final block = _readCallBlock(lines, index);
    for (var offset = 0; offset < block.lines.length; offset += 1) {
      final line = _withoutLineComment(block.lines[offset]);
      if (!_textStyleVisualPropertyPattern.hasMatch(line)) continue;

      violations.add(
        _violation(
          ruleId: 'ds.typography.inline',
          path: file.path,
          line: index + offset + 1,
          snippet: block.lines[offset],
          remediation:
              'Use context.typography tokens and copyWith only for semantic variants.',
        ),
      );
      return;
    }
  }

  void _scanSpacingRadiusElevation(
    _SourceFile file,
    List<String> lines,
    int index,
    List<_Violation> violations,
  ) {
    final line = _withoutLineComment(lines[index]);

    if (_edgeInsetsStartPattern.hasMatch(line)) {
      _addBlockViolationWhenNumeric(
        ruleId: 'ds.spacing.inline',
        file: file,
        lines: lines,
        index: index,
        violations: violations,
        remediation:
            'Use context.spacing tokens instead of ad-hoc EdgeInsets literals.',
      );
    }

    if (_radiusStartPattern.hasMatch(line)) {
      _addBlockViolationWhenNumeric(
        ruleId: 'ds.radius.inline',
        file: file,
        lines: lines,
        index: index,
        violations: violations,
        remediation:
            'Use context.radius tokens instead of ad-hoc radius literals.',
      );
    }

    if (_elevationLiteralPattern.hasMatch(line)) {
      violations.add(
        _violation(
          ruleId: 'ds.elevation.inline',
          path: file.path,
          line: index + 1,
          snippet: lines[index],
          remediation:
              'Use context.elevation tokens instead of ad-hoc elevation values.',
        ),
      );
    }

    if (_boxShadowStartPattern.hasMatch(line)) {
      final block = _readCallBlock(lines, index);
      if (_boxShadowNumericPattern.hasMatch(block.joined) &&
          _numberLiteralPattern.hasMatch(block.joined)) {
        violations.add(
          _violation(
            ruleId: 'ds.elevation.inline',
            path: file.path,
            line: index + 1,
            snippet: lines[index],
            remediation:
                'Use AppElevation/context.elevation instead of custom shadow literals.',
          ),
        );
      }
    }
  }

  void _scanVisualSizeLiterals(
    _SourceFile file,
    List<String> lines,
    int index,
    List<_Violation> violations,
  ) {
    final line = _withoutLineComment(lines[index]);
    if (!_visualSizeStartPattern.hasMatch(line)) return;

    final ownArguments = _readTopLevelCallArguments(lines, index);
    if (!_visualNumericPropertyPattern.hasMatch(line) &&
        !_visualNumericPropertyPattern.hasMatch(ownArguments)) {
      return;
    }

    violations.add(
      _violation(
        ruleId: 'ds.size.inline',
        path: file.path,
        line: index + 1,
        snippet: lines[index],
        remediation:
            'Use context.spacing/radius/typography tokens or a reviewed component-owned size instead of ad-hoc visual dimensions.',
      ),
    );
  }

  void _addBlockViolationWhenNumeric({
    required String ruleId,
    required _SourceFile file,
    required List<String> lines,
    required int index,
    required List<_Violation> violations,
    required String remediation,
  }) {
    final block = _readCallBlock(lines, index);
    if (!_numberLiteralPattern.hasMatch(block.joined)) return;

    violations.add(
      _violation(
        ruleId: ruleId,
        path: file.path,
        line: index + 1,
        snippet: lines[index],
        remediation: remediation,
      ),
    );
  }

  void _scanDirectMaterialPrimitive(
    _SourceFile file,
    String line,
    int index,
    List<_Violation> violations,
  ) {
    final primitive = _directMaterialPrimitive(line);
    if (primitive == null) return;

    violations.add(
      _violation(
        ruleId: 'ds.material.primitive',
        path: file.path,
        line: index + 1,
        snippet: line,
        remediation: _materialPrimitiveRemediation(primitive),
      ),
    );
  }

  void _scanThemeExtensionFallback(
    _SourceFile file,
    String line,
    int index,
    List<_Violation> violations,
  ) {
    if (!_themeFallbackPattern.hasMatch(line)) return;

    violations.add(
      _violation(
        ruleId: 'ds.theme_extension.fallback',
        path: file.path,
        line: index + 1,
        snippet: line,
        remediation:
            'Use context.colors/spacing/radius/typography/elevation helpers and fail loudly if the extension is missing.',
      ),
    );
  }
}

bool _disallowsAppVisualPrimitives(String path) {
  if (path.startsWith('lib/core/theme/') || path.startsWith('lib/ui/')) {
    return false;
  }

  return path == 'lib/main.dart' ||
      path.startsWith('lib/app/') ||
      path.startsWith('lib/features/');
}

String? _directMaterialPrimitive(String line) {
  if (_filledButtonConstructorPattern.hasMatch(line)) return 'FilledButton';
  if (_textButtonConstructorPattern.hasMatch(line)) return 'TextButton';
  if (_textFieldConstructorPattern.hasMatch(line)) return 'TextField';
  if (_cardConstructorPattern.hasMatch(line)) return 'Card';
  if (_alertDialogConstructorPattern.hasMatch(line)) return 'AlertDialog';
  if (_bottomSheetFunctionPattern.hasMatch(line)) return 'showModalBottomSheet';
  return null;
}

String _materialPrimitiveRemediation(String primitive) {
  return switch (primitive) {
    'FilledButton' => 'Use PrimaryButton from lib/ui/app_button.dart.',
    'TextButton' => 'Use AppTextButton from lib/ui/app_button.dart.',
    'TextField' => 'Use AppTextField from lib/ui/app_text_field.dart.',
    'Card' => 'Use AppCard or another lib/ui wrapper before adding Card.',
    'AlertDialog' => 'Use AppDialog from lib/ui/app_dialog.dart.',
    'showModalBottomSheet' =>
      'Use showAppBottomSheet from lib/ui/app_bottom_sheet.dart.',
    _ => 'Use the Matome lib/ui wrapper for this Material primitive.',
  };
}

_CallBlock _readCallBlock(List<String> lines, int startIndex) {
  final blockLines = <String>[];
  var depth = 0;
  var sawOpen = false;

  for (var index = startIndex; index < lines.length; index += 1) {
    final line = _withoutLineComment(lines[index]);
    blockLines.add(lines[index]);

    for (final unit in line.codeUnits) {
      if (unit == 40) {
        depth += 1;
        sawOpen = true;
      } else if (unit == 41 && sawOpen) {
        depth -= 1;
      }
    }

    if (sawOpen && depth <= 0) break;
  }

  return _CallBlock(blockLines);
}

String _readTopLevelCallArguments(List<String> lines, int startIndex) {
  final parts = <String>[];
  var depth = 0;
  var sawOpen = false;

  for (var index = startIndex; index < lines.length; index += 1) {
    final line = _withoutLineComment(lines[index]);
    final topLevel = StringBuffer();

    for (final unit in line.codeUnits) {
      if (unit == 40) {
        if (sawOpen && depth == 1) topLevel.writeCharCode(unit);
        depth += 1;
        sawOpen = true;
      } else if (unit == 41 && sawOpen) {
        if (depth > 1) topLevel.writeCharCode(unit);
        depth -= 1;
      } else if (sawOpen && depth == 1) {
        topLevel.writeCharCode(unit);
      }
    }

    final text = topLevel.toString().trim();
    if (text.isNotEmpty) parts.add(text);
    if (sawOpen && depth <= 0) break;
  }

  return parts.join('\n');
}

_Violation _violation({
  required String ruleId,
  required String path,
  required int line,
  required String snippet,
  required String remediation,
}) {
  return _Violation(
    ruleId: ruleId,
    path: path,
    line: line,
    snippet: _stableSnippet(snippet),
    remediation: remediation,
  );
}

String _withoutLineComment(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return '';

  final index = line.indexOf('//');
  if (index == -1) return line;
  return line.substring(0, index);
}

String _stableSnippet(String line) {
  return line.trim().replaceAll(RegExp(r'\s+'), ' ');
}

final _hardcodedColorPattern = RegExp(
  r'\b(?:Color\s*\(\s*0x[0-9a-fA-F]{6,8}|Color\.from(?:ARGB|RGBO)\s*\()',
);
final _materialColorPattern = RegExp(r'\bColors\.[A-Za-z_][A-Za-z0-9_]*\b');
final _textStyleStartPattern = RegExp(r'\bTextStyle\s*\(');
final _textStyleVisualPropertyPattern = RegExp(
  r'\b(?:fontSize|color|fontWeight|height|letterSpacing)\s*:',
);
final _edgeInsetsStartPattern = RegExp(
  r'\bEdgeInsets\.(?:all|symmetric|fromLTRB|only)\s*\(',
);
final _radiusStartPattern = RegExp(r'\b(?:BorderRadius|Radius)\.circular\s*\(');
final _elevationLiteralPattern = RegExp(r'\belevation\s*:\s*-?\d+(?:\.\d+)?\b');
final _boxShadowStartPattern = RegExp(r'\bBoxShadow\s*\(');
final _boxShadowNumericPattern = RegExp(
  r'\b(?:blurRadius|spreadRadius|offset)\s*:',
);
final _numberLiteralPattern = RegExp(r'(?:^|[^A-Za-z0-9_])-?\d+(?:\.\d+)?');
final _visualSizeStartPattern = RegExp(
  r'\b(?:AnimatedContainer|Avatar|BoxConstraints|CircleAvatar|ConstrainedBox|Container|Icon|LoadingIndicator|Positioned|Size(?:\.\w+)?|SizedBox(?:\.\w+)?|Wrap)\s*\(',
);
final _visualNumericPropertyPattern = RegExp(
  r'\b(?:bottom|dimension|height|iconSize|left|maxHeight|maxWidth|maximumSize|minHeight|minWidth|minimumSize|right|runSpacing|size|spacing|strokeWidth|top|width)\s*:\s*[^,\n)]*-?\d',
);
final _filledButtonConstructorPattern = RegExp(
  r'\bFilledButton\s*(?:\.\s*icon)?\s*\(',
);
final _textButtonConstructorPattern = RegExp(
  r'\bTextButton\s*(?:\.\s*icon)?\s*\(',
);
final _textFieldConstructorPattern = RegExp(r'\bTextField\s*\(');
final _cardConstructorPattern = RegExp(r'\bCard\s*\(');
final _alertDialogConstructorPattern = RegExp(r'\bAlertDialog\s*\(');
final _bottomSheetFunctionPattern = RegExp(
  r'\bshowModalBottomSheet(?:<[^>]+>)?\s*\(',
);
final _themeFallbackPattern = RegExp(
  r'(?:\.extension<[^>]+>\s*\(\s*\)\s*\?\?|\?\?\s*MatomeColors\.(?:light|dark)\b)',
);

final class _GuardResult {
  const _GuardResult({
    required this.violations,
    required this.unreviewedViolations,
    required this.staleBaseline,
    required this.invalidBaseline,
    required this.duplicateBaseline,
    required this.expiredBaseline,
  });

  final List<_Violation> violations;
  final List<_Violation> unreviewedViolations;
  final List<_BaselineEntry> staleBaseline;
  final List<_BaselineEntry> invalidBaseline;
  final List<_BaselineEntry> duplicateBaseline;
  final List<_BaselineEntry> expiredBaseline;

  String? get failureMessage {
    if (unreviewedViolations.isEmpty &&
        staleBaseline.isEmpty &&
        invalidBaseline.isEmpty &&
        duplicateBaseline.isEmpty &&
        expiredBaseline.isEmpty) {
      return null;
    }

    final buffer = StringBuffer()
      ..writeln('Design-system source guard failed.')
      ..writeln('Scanned only apps/flutter/lib/**/*.dart production source.')
      ..writeln('Total current violations: ${violations.length}')
      ..writeln(
        'Remaining reviewed baseline: ${violations.length - unreviewedViolations.length}',
      );

    if (unreviewedViolations.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Unreviewed violations:');
      for (final violation in unreviewedViolations) {
        buffer
          ..writeln('- ${violation.ruleId} ${violation.path}:${violation.line}')
          ..writeln('  snippet: ${violation.snippet}')
          ..writeln('  remediation: ${violation.remediation}')
          ..writeln('  baseline: ${violation.toBaselineConstructor()}');
      }
    }

    if (staleBaseline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Stale baseline entries to delete:');
      for (final entry in staleBaseline) {
        buffer.writeln('- ${entry.ruleId} ${entry.path}:${entry.line}');
      }
    }

    if (invalidBaseline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Invalid baseline entries missing owner/reason/expiry:');
      for (final entry in invalidBaseline) {
        buffer.writeln('- ${entry.ruleId} ${entry.path}:${entry.line}');
      }
    }

    if (duplicateBaseline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Duplicate baseline entries:');
      for (final entry in duplicateBaseline) {
        buffer.writeln('- ${entry.ruleId} ${entry.path}:${entry.line}');
      }
    }

    if (expiredBaseline.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Expired baseline entries:');
      for (final entry in expiredBaseline) {
        buffer.writeln(
          '- ${entry.ruleId} ${entry.path}:${entry.line} expired ${entry.expires}',
        );
      }
    }

    return buffer.toString();
  }
}

final class _SourceFile {
  const _SourceFile({required this.path, required this.content});

  final String path;
  final String content;
}

final class _CallBlock {
  const _CallBlock(this.lines);

  final List<String> lines;

  String get joined => lines.map(_withoutLineComment).join('\n');
}

final class _Violation {
  const _Violation({
    required this.ruleId,
    required this.path,
    required this.line,
    required this.snippet,
    required this.remediation,
  });

  final String ruleId;
  final String path;
  final int line;
  final String snippet;
  final String remediation;

  String get key => '$ruleId|$path|$line|$snippet';

  String toBaselineConstructor() {
    return "_BaselineEntry(ruleId: '$ruleId', path: '$path', line: $line, "
        "snippet: '${_escapeDartString(snippet)}', owner: 'design-system', "
        "reason: 'Existing violation captured by W2 baseline.', "
        "expires: '2027-01-31'),";
  }
}

final class _BaselineEntry {
  const _BaselineEntry({
    required this.ruleId,
    required this.path,
    required this.line,
    required this.snippet,
    required this.owner,
    required this.reason,
    required this.expires,
  });

  final String ruleId;
  final String path;
  final int line;
  final String snippet;
  final String owner;
  final String reason;
  final String expires;

  String get key => '$ruleId|$path|$line|$snippet';

  bool get isWellFormed {
    return owner.trim().isNotEmpty &&
        reason.trim().isNotEmpty &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expires);
  }

  bool get isExpired {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expires)) return true;
    final expiry = DateTime.parse(expires);
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    return expiry.isBefore(currentDate);
  }
}

String _escapeDartString(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

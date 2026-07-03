import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';

void main() {
  test('pg item_type, OpenAPI enum, and Dart enum stay aligned', () {
    final dart = MatomeItemType.values.map((type) => type.wireName).toList();
    expect(dart, ['file', 'text']);

    final root = Directory.current.parent.parent;
    final migration = File(
      '${root.path}/services/api/priv/repo/migrations/'
      '20260702000000_replace_recordings_with_items.exs',
    ).readAsStringSync();
    final ecto = File(
      '${root.path}/services/api/lib/matome_api/content/item.ex',
    ).readAsStringSync();
    final openApi = File(
      '${root.path}/services/api/lib/matome_api_web/api_spec.ex',
    ).readAsStringSync();

    expect(_pgItemTypeValues(migration), dart);
    expect(_ectoItemTypeValues(ecto), dart);
    expect(_openApiItemTypeValues(openApi), dart);
  });

  test('new item types add no per-type switch sites outside canonical mapping', () {
    final root = Directory.current;
    final lib = Directory('${root.path}/lib');
    final violations = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('/features/items/matome_item_type.dart')) {
        continue;
      }

      final source = entity.readAsStringSync();
      if (scattersItemTypeDispatch(source)) {
        violations.add(entity.path.replaceFirst('${root.path}/', ''));
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Item-type dispatch must stay in features/items/matome_item_type.dart '
          '(use mapMatomeItemType). A hypothetical new item type should not '
          'require scattering new switch sites.',
    );
  });

  test('the guard catches per-type switch sites that the old regex evaded', () {
    // Regression for I3: the old regex only matched `switch(...itemType...)` /
    // `switch(...MatomeItemType...)`, so a switch over a value named `type` —
    // as in the former items_dao `_rowWithPayload` — slipped straight through.
    const evadingSwitchOnType = '''
      MatomeItemWithPayload _rowWithPayload(TypedResult row) {
        final type = matomeItemTypeFromWire(row.itemType);
        return switch (type) {
          MatomeItemType.file => a,
          MatomeItemType.text => b,
        };
      }
    ''';
    const evadingCaseArms = '''
      switch (something) {
        case MatomeItemType.file:
          return a;
        case MatomeItemType.text:
          return b;
      }
    ''';

    expect(
      scattersItemTypeDispatch(evadingSwitchOnType),
      isTrue,
      reason: 'a `switch (type)` with MatomeItemType arms must be caught',
    );
    expect(
      scattersItemTypeDispatch(evadingCaseArms),
      isTrue,
      reason: 'MatomeItemType case arms must be caught',
    );

    // The old explicit forms are still caught…
    expect(
      scattersItemTypeDispatch('switch (item.itemType) { }'),
      isTrue,
    );
    // …and a mere equality comparison (the tile getters) is NOT a violation:
    // it does not branch per-type, so it must stay allowed.
    expect(
      scattersItemTypeDispatch(
        'bool get isFile => item.itemType == MatomeItemType.file;',
      ),
      isFalse,
      reason: 'an `== MatomeItemType.file` comparison is not scattered dispatch',
    );
    // A mediaType routing switch is a DIFFERENT discriminator and stays allowed.
    expect(
      scattersItemTypeDispatch('final p = switch (mediaType) { };'),
      isFalse,
    );
  });
}

/// Whether [source] scatters per-item-type dispatch outside the canonical
/// `features/items/matome_item_type.dart` home. Catches BOTH the explicit
/// `switch (...itemType...)` / `switch (...MatomeItemType...)` forms AND a
/// switch whose case arms name `MatomeItemType.<value>` (the form that evaded
/// the original regex when the scrutinee was named `type`). A bare
/// `== MatomeItemType.x` comparison is deliberately NOT matched — it does not
/// branch per type.
bool scattersItemTypeDispatch(String source) {
  final explicitSwitch = RegExp(
    r'switch\s*\([^\)]*itemType[^\)]*\)|switch\s*\([^\)]*MatomeItemType[^\)]*\)',
  ).hasMatch(source);
  // A `MatomeItemType.<value>` used as a switch/pattern case arm: either the
  // pattern-arrow form `MatomeItemType.file =>` or the classic `case
  // MatomeItemType.file:`. The trailing `=>`/`:` is what distinguishes a case
  // arm from an equality comparison (`== MatomeItemType.file;`).
  final caseArm = RegExp(
    r'MatomeItemType\.\w+\s*(=>|:)',
  ).hasMatch(source);
  return explicitSwitch || caseArm;
}

List<String> _pgItemTypeValues(String source) {
  final match = RegExp(r"item_type IN \(([^)]*)\)").firstMatch(source);
  expect(match, isNotNull);
  return RegExp(r"'([^']+)'")
      .allMatches(match!.group(1)!)
      .map((match) => match.group(1)!)
      .toList(growable: false);
}

List<String> _ectoItemTypeValues(String source) {
  final match = RegExp(r'@item_types \[([^\]]*)\]').firstMatch(source);
  expect(match, isNotNull);
  return RegExp(r':([a-z_]+)')
      .allMatches(match!.group(1)!)
      .map((match) => match.group(1)!)
      .toList(growable: false);
}

List<String> _openApiItemTypeValues(String source) {
  final match = RegExp(
    r'item_type: %OpenApiSpex\.Schema\{[^}]*enum: \[([^\]]*)\]',
    dotAll: true,
  ).firstMatch(source);
  expect(match, isNotNull);
  return RegExp(r'"([^"]+)"')
      .allMatches(match!.group(1)!)
      .map((match) => match.group(1)!)
      .toList(growable: false);
}

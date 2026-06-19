import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/features/matome/matome_summary.dart';

/// Pure-function tests for the deterministic local aggregated-summary generator
/// and the sparse-sync null-wipe merge guard (Omakiten #1376, ADR-0003).

RecordingItem _item({
  required String id,
  String title = 'Item',
  String? summary,
}) {
  return RecordingItem(
    id: id,
    title: title,
    summary: summary,
    timestamp: '9:00 AM',
    duration: '0:30',
    badge: 'Inbox',
    isProcessing: false,
    mediaType: 'audio',
    processingStatus: 'done',
  );
}

void main() {
  group('composeAggregatedSummary', () {
    test('composes a header + per-item bullet for items WITH a summary', () {
      final out = composeAggregatedSummary([
        _item(id: 'a', title: 'Kickoff', summary: 'Agreed on scope.'),
        _item(id: 'b', title: 'Design review', summary: 'Picked layout B.'),
      ]);

      expect(out, isNotNull);
      expect(out, contains('2 recordings'));
      expect(out, contains('• Kickoff: Agreed on scope.'));
      expect(out, contains('• Design review: Picked layout B.'));
      // Header first, then a blank line, then the bullets in input order.
      expect(
        out,
        '2 recordings\n'
        '\n'
        '• Kickoff: Agreed on scope.\n'
        '• Design review: Picked layout B.',
      );
    });

    test('singular header for exactly one contributing item', () {
      final out = composeAggregatedSummary([
        _item(id: 'a', title: 'Note', summary: 'Quick thought.'),
      ]);
      expect(out, startsWith('1 recording\n'));
      expect(out, isNot(contains('1 recordings')));
    });

    test('skips items with a null/blank summary; counts only contributors', () {
      final out = composeAggregatedSummary([
        _item(id: 'a', title: 'Has summary', summary: 'Kept.'),
        _item(id: 'b', title: 'Photo', summary: null),
        _item(id: 'c', title: 'Blank', summary: '   '),
        _item(id: 'd', title: 'Also kept', summary: 'Second.'),
      ]);

      expect(out, isNotNull);
      // Only the two contributing items are counted + listed.
      expect(out, contains('2 recordings'));
      expect(out, contains('• Has summary: Kept.'));
      expect(out, contains('• Also kept: Second.'));
      expect(out, isNot(contains('Photo')));
      expect(out, isNot(contains('Blank')));
    });

    test('returns null when no item has a summary (0-summary case)', () {
      expect(
        composeAggregatedSummary([
          _item(id: 'a', summary: null),
          _item(id: 'b', summary: ''),
        ]),
        isNull,
      );
      expect(composeAggregatedSummary(const []), isNull);
    });

    test('falls back to "Untitled" for a blank title', () {
      final out = composeAggregatedSummary([
        _item(id: 'a', title: '   ', summary: 'Body.'),
      ]);
      expect(out, contains('• Untitled: Body.'));
    });

    test('is deterministic — same input yields identical output', () {
      final items = [
        _item(id: 'a', title: 'One', summary: 'Alpha.'),
        _item(id: 'b', title: 'Two', summary: 'Beta.'),
      ];
      expect(
        composeAggregatedSummary(items),
        composeAggregatedSummary(items),
      );
    });
  });

  group('mergeAggregatedSummary (sparse-sync null-wipe guard)', () {
    test('keeps the local value when incoming is null', () {
      expect(mergeAggregatedSummary(null), const Value<String?>.absent());
    });

    test('keeps the local value when incoming is empty/blank', () {
      expect(mergeAggregatedSummary(''), const Value<String?>.absent());
      expect(mergeAggregatedSummary('   '), const Value<String?>.absent());
    });

    test('adopts a non-empty incoming value (trimmed)', () {
      final merged = mergeAggregatedSummary('  fresh aggregate  ');
      expect(merged.present, isTrue);
      expect(merged.value, 'fresh aggregate');
    });
  });
}

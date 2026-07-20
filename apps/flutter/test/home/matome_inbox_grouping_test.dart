import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/features/home/matome_inbox_grouping.dart';

MatomeItem _matome({
  required String id,
  String title = 'Untitled',
  String? description,
  String? aggregatedSummary,
  List<RecordingItem> recordings = const [],
  required DateTime happenedAt,
}) {
  return MatomeItem(
    id: id,
    spaceId: null,
    title: title,
    happenedAt: happenedAt.millisecondsSinceEpoch,
    createdAt: happenedAt.millisecondsSinceEpoch,
    summaryStale: false,
    recordingCount: recordings.length,
    recordings: recordings,
    description: description,
    aggregatedSummary: aggregatedSummary,
  );
}

RecordingItem _rec({String title = 'Rec', String? summary, String? notes}) {
  return RecordingItem(
    id: 't',
    title: title,
    summary: summary,
    timestamp: '9:00 AM',
    duration: '0:30',
    badge: 'Inbox',
    notes: notes,
    isProcessing: false,
    mediaType: 'audio',
    processingStatus: 'done',
  );
}

void main() {
  final now = DateTime(2026, 6, 8, 14, 0);

  group('searchMatomes', () {
    final items = [
      _matome(id: '1', title: 'Standup notes', happenedAt: now),
      _matome(
        id: '2',
        title: 'Idea dump',
        description: 'rocket plans',
        happenedAt: now,
      ),
      _matome(
        id: '3',
        title: 'Groceries',
        recordings: [_rec(title: 'milk', summary: 'weekly sync')],
        happenedAt: now,
      ),
    ];

    test('empty query returns all', () {
      expect(searchMatomes(items, '').length, 3);
    });

    test('matches matome title', () {
      expect(searchMatomes(items, 'standup').map((m) => m.id), ['1']);
    });

    test('matches matome description (notes)', () {
      expect(searchMatomes(items, 'rocket').map((m) => m.id), ['2']);
    });

    test('matches a child recording summary', () {
      expect(searchMatomes(items, 'sync').map((m) => m.id), ['3']);
    });

    test('is case-insensitive', () {
      expect(searchMatomes(items, 'STANDUP').map((m) => m.id), ['1']);
    });
  });

  group('groupMatomesByDate', () {
    test('buckets into Today / Yesterday / older, in order', () {
      final items = [
        _matome(id: 'today', happenedAt: now),
        _matome(id: 'yest', happenedAt: now.subtract(const Duration(days: 1))),
        _matome(id: 'old', happenedAt: now.subtract(const Duration(days: 5))),
      ];
      final sections = groupMatomesByDate(
        items,
        todayLabel: 'Today',
        yesterdayLabel: 'Yesterday',
        now: now,
      );
      expect(sections.map((s) => s.title).take(2), ['Today', 'Yesterday']);
      expect(sections.first.items.single.id, 'today');
      expect(sections[1].items.single.id, 'yest');
      expect(sections.length, 3);
      expect(sections.last.items.single.id, 'old');
    });

    test('empty list yields no sections', () {
      expect(
        groupMatomesByDate(
          [],
          todayLabel: 'Today',
          yesterdayLabel: 'Yesterday',
        ),
        isEmpty,
      );
    });

    test('older dated sections sort newest-first', () {
      final items = [
        _matome(id: 'a', happenedAt: now.subtract(const Duration(days: 3))),
        _matome(id: 'b', happenedAt: now.subtract(const Duration(days: 9))),
      ];
      final sections = groupMatomesByDate(
        items,
        todayLabel: 'Today',
        yesterdayLabel: 'Yesterday',
        now: now,
      );
      expect(sections.first.items.single.id, 'a');
      expect(sections.last.items.single.id, 'b');
    });
  });
}

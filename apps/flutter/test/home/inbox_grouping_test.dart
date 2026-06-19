import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/features/home/inbox_grouping.dart';
import 'package:matome_flutter/features/home/inbox_item.dart';

InboxItem _item({
  required String id,
  String title = 'Untitled',
  String? summary,
  String? notes,
  required DateTime createdAt,
}) {
  return InboxItem(
    card: RecordingItem(
      id: id,
      title: title,
      summary: summary,
      timestamp: '9:00 AM',
      duration: '0:30',
      badge: 'Inbox',
      notes: notes,
      isProcessing: false,
      mediaType: 'audio',
      processingStatus: 'done',
    ),
    createdAt: createdAt.millisecondsSinceEpoch,
  );
}

void main() {
  final now = DateTime(2026, 6, 8, 14, 0);

  group('searchItems', () {
    final items = [
      _item(
        id: '1',
        title: 'Standup notes',
        summary: 'weekly sync',
        createdAt: now,
      ),
      _item(id: '2', title: 'Idea dump', notes: 'rocket plans', createdAt: now),
      _item(id: '3', title: 'Groceries', createdAt: now),
    ];

    test('empty query returns all', () {
      expect(searchItems(items, '').length, 3);
    });

    test('matches title', () {
      final r = searchItems(items, 'groc');
      expect(r.map((i) => i.id), ['3']);
    });

    test('matches summary', () {
      final r = searchItems(items, 'sync');
      expect(r.map((i) => i.id), ['1']);
    });

    test('matches notes', () {
      final r = searchItems(items, 'rocket');
      expect(r.map((i) => i.id), ['2']);
    });

    test('is case-insensitive', () {
      expect(searchItems(items, 'STANDUP').map((i) => i.id), ['1']);
    });
  });

  group('groupByDate', () {
    test('buckets into Today / Yesterday / older, in order', () {
      final items = [
        _item(id: 'today', createdAt: now),
        _item(id: 'yest', createdAt: now.subtract(const Duration(days: 1))),
        _item(id: 'old', createdAt: now.subtract(const Duration(days: 5))),
      ];
      final sections = groupByDate(
        items,
        todayLabel: 'Today',
        yesterdayLabel: 'Yesterday',
        now: now,
      );
      expect(sections.map((s) => s.title).take(2), ['Today', 'Yesterday']);
      expect(sections.first.items.single.id, 'today');
      expect(sections[1].items.single.id, 'yest');
      // The 5-days-ago item lands in its own dated section.
      expect(sections.length, 3);
      expect(sections.last.items.single.id, 'old');
    });

    test('empty list yields no sections', () {
      expect(
        groupByDate([], todayLabel: 'Today', yesterdayLabel: 'Yesterday'),
        isEmpty,
      );
    });

    test('older dated sections sort newest-first', () {
      final items = [
        _item(id: 'a', createdAt: now.subtract(const Duration(days: 3))),
        _item(id: 'b', createdAt: now.subtract(const Duration(days: 9))),
      ];
      final sections = groupByDate(
        items,
        todayLabel: 'Today',
        yesterdayLabel: 'Yesterday',
        now: now,
      );
      expect(sections.first.items.single.id, 'a'); // 3d ago before 9d ago
      expect(sections.last.items.single.id, 'b');
    });
  });
}

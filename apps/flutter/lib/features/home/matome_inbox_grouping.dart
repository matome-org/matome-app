import '../../core/db/matome_card.dart';
import 'inbox_grouping.dart' show sectionTitleFor;

/// Pure search + date-grouping for the matome-centric Inbox (#1378). Mirrors
/// `inbox_grouping.dart` but operates on [MatomeItem]s (the top-level unit) and
/// groups by `happenedAt` (the matome's happening), newest-first.
///
/// Kept free of Flutter/DB imports so it is trivially unit-testable.

/// Filters [items] by a free-text [query] over the matome title plus any child
/// recording title / summary / notes (case-insensitive). Empty query returns
/// the list unchanged.
List<MatomeItem> searchMatomes(List<MatomeItem> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items
      .where((item) {
        if (item.title.toLowerCase().contains(q)) return true;
        if ((item.description ?? '').toLowerCase().contains(q)) return true;
        if ((item.aggregatedSummary ?? '').toLowerCase().contains(q)) {
          return true;
        }
        for (final rec in item.recordings) {
          if (rec.title.toLowerCase().contains(q)) return true;
          if ((rec.summary ?? '').toLowerCase().contains(q)) return true;
          if ((rec.notes ?? '').toLowerCase().contains(q)) return true;
        }
        return false;
      })
      .toList(growable: false);
}

/// A titled group of inbox matomes (Today / Yesterday / "Mon D[, YYYY]").
class MatomeSection {
  const MatomeSection({required this.title, required this.items});

  final String title;
  final List<MatomeItem> items;
}

/// Groups [items] (already newest-first by happenedAt) into date sections.
/// Today first, then Yesterday, then other dates newest-first. Empty sections
/// are dropped. Mirrors `groupByDate` for [MatomeItem]s.
List<MatomeSection> groupMatomesByDate(
  List<MatomeItem> items, {
  required String todayLabel,
  required String yesterdayLabel,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final order = <String>[];
  final buckets = <String, List<MatomeItem>>{};
  final repDay = <String, DateTime>{};

  DateTime startOfDay(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  for (final item in items) {
    final title = sectionTitleFor(
      item.happenedAt,
      todayLabel: todayLabel,
      yesterdayLabel: yesterdayLabel,
      now: reference,
    );
    if (!buckets.containsKey(title)) {
      buckets[title] = [];
      order.add(title);
      repDay[title] = startOfDay(item.happenedAt);
    }
    buckets[title]!.add(item);
  }

  order.sort((a, b) {
    if (a == todayLabel) return -1;
    if (b == todayLabel) return 1;
    if (a == yesterdayLabel) return -1;
    if (b == yesterdayLabel) return 1;
    return repDay[b]!.compareTo(repDay[a]!);
  });

  return order
      .map((title) => MatomeSection(title: title, items: buckets[title]!))
      .toList(growable: false);
}

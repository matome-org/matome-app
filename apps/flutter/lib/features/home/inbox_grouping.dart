import 'inbox_item.dart';

/// Pure search + date-grouping for the Inbox, ported from apps/mobile
/// processes/homeData.ts (fetchHomeData -> getSectionTitle / sort).
///
/// Kept free of Flutter/DB imports so it is trivially unit-testable.

/// Filters [items] by a free-text [query] over title / summary / notes
/// (case-insensitive). Empty query returns the list unchanged.
List<InboxItem> searchItems(List<InboxItem> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items
      .where((item) {
        final card = item.card;
        final title = card.title.toLowerCase();
        final summary = (card.summary ?? '').toLowerCase();
        final notes = (card.notes ?? '').toLowerCase();
        return title.contains(q) || summary.contains(q) || notes.contains(q);
      })
      .toList(growable: false);
}

/// Midnight (local) for the day containing [epochMs].
DateTime _startOfDay(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  return DateTime(d.year, d.month, d.day);
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Section title for a recording day, mirroring mobile getSectionTitle:
/// "Today" / "Yesterday" / "Mon D" (this year) / "Mon D, YYYY" (other years).
String sectionTitleFor(
  int createdAtMs, {
  required String todayLabel,
  required String yesterdayLabel,
  DateTime? now,
}) {
  final today = _startOfDay((now ?? DateTime.now()).millisecondsSinceEpoch);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = _startOfDay(createdAtMs);

  if (day == today) return todayLabel;
  if (day == yesterday) return yesterdayLabel;

  final month = _months[day.month - 1];
  if (day.year == today.year) return '$month ${day.day}';
  return '$month ${day.day}, ${day.year}';
}

/// Groups [items] (already newest-first) into date sections. Today first, then
/// Yesterday, then other dates newest-first. Empty sections are dropped.
List<InboxSection> groupByDate(
  List<InboxItem> items, {
  required String todayLabel,
  required String yesterdayLabel,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final order = <String>[];
  final buckets = <String, List<InboxItem>>{};
  final repDay = <String, DateTime>{};

  for (final item in items) {
    final title = sectionTitleFor(
      item.createdAt,
      todayLabel: todayLabel,
      yesterdayLabel: yesterdayLabel,
      now: reference,
    );
    if (!buckets.containsKey(title)) {
      buckets[title] = [];
      order.add(title);
      repDay[title] = _startOfDay(item.createdAt);
    }
    buckets[title]!.add(item);
  }

  order.sort((a, b) {
    if (a == todayLabel) return -1;
    if (b == todayLabel) return 1;
    if (a == yesterdayLabel) return -1;
    if (b == yesterdayLabel) return 1;
    return repDay[b]!.compareTo(repDay[a]!); // newest day first
  });

  return order
      .map((title) => InboxSection(title: title, items: buckets[title]!))
      .toList(growable: false);
}

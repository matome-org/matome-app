import '../recordings/recording.dart';

/// The Home filter chips, in display order. `all` shows everything.
enum HomeFilter {
  all('All'),
  today('Today'),
  work('Work'),
  ideas('Ideas'),
  unresolved('Unresolved');

  const HomeFilter(this.label);

  final String label;
}

/// A titled group of recordings rendered as one `HomeSection`.
class HomeSection {
  const HomeSection({required this.title, required this.recordings});

  final String title;
  final List<Recording> recordings;
}

/// `true` when [recording] was inserted on the same calendar day as [now].
bool _isToday(Recording recording, DateTime now) {
  final inserted = recording.insertedAt?.toLocal();
  if (inserted == null) return false;
  return inserted.year == now.year &&
      inserted.month == now.month &&
      inserted.day == now.day;
}

bool _matchesBadge(Recording recording, String badge) {
  return (recording.badge ?? '').toLowerCase() == badge.toLowerCase();
}

/// Applies the active chip filter, then the free-text search (title/summary),
/// entirely client-side. Pure so it can be unit/widget tested without a backend.
List<Recording> applyFilters({
  required List<Recording> recordings,
  required HomeFilter filter,
  required String search,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final query = search.trim().toLowerCase();

  return recordings.where((r) {
    final passesChip = switch (filter) {
      HomeFilter.all => true,
      HomeFilter.today => _isToday(r, today),
      HomeFilter.work => _matchesBadge(r, 'work'),
      HomeFilter.ideas => _matchesBadge(r, 'ideas'),
      HomeFilter.unresolved => r.status == RecordingStatus.failed,
    };
    if (!passesChip) return false;

    if (query.isEmpty) return true;
    final title = r.title.toLowerCase();
    final summary = (r.summary ?? '').toLowerCase();
    return title.contains(query) || summary.contains(query);
  }).toList(growable: false);
}

/// Groups the (already-filtered) recordings into "Today" / "Earlier" sections.
/// Empty sections are dropped so the UI never renders a bare header.
List<HomeSection> groupIntoSections(
  List<Recording> recordings, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final todayItems = <Recording>[];
  final earlierItems = <Recording>[];

  for (final r in recordings) {
    if (_isToday(r, today)) {
      todayItems.add(r);
    } else {
      earlierItems.add(r);
    }
  }

  return [
    if (todayItems.isNotEmpty)
      HomeSection(title: 'Today', recordings: todayItems),
    if (earlierItems.isNotEmpty)
      HomeSection(title: 'Earlier', recordings: earlierItems),
  ];
}

/// Short relative timestamp shown on the card (e.g. "3h", "2d", "now").
String formatTimestamp(DateTime? when, {DateTime? now}) {
  if (when == null) return '';
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${diff.inDays ~/ 7}w';
}

/// Formats a duration (seconds) as `m:ss`; empty when unknown.
String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

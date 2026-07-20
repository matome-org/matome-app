// Display formatters shared by the Inbox cards. Pure so they unit-test without
// a backend. (The chip-filter / section-grouping helpers that previously lived
// here were superseded by `inbox_grouping.dart`, which groups the Drift-backed
// InboxItem list by date.)

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

import 'package:drift/drift.dart' show Value;

import '../../core/db/recording_card.dart';

/// Local, deterministic composition of a Matome's `aggregatedSummary` from its
/// child Items (recordings) — ADR-0003.
///
/// This is the W1 stand-in for the eventual Core-AI aggregation: NO backend /
/// AI call. It rolls each Item that carries a non-empty `summary` into a titled
/// bullet, under a "N recordings" header, producing readable Markdown the hub
/// already renders via `MarkdownBody`. The Core-AI generator can replace this
/// function later (sync/backend wave) without touching the storage/staleness
/// plumbing built around it.
///
/// Rules (deterministic, order-preserving over [recordings]):
///   * Items with a null/blank `summary` are skipped (a photo/pending Item
///     contributes no prose).
///   * Each contributing Item becomes a `• <title>: <summary>` line, with the
///     title falling back to "Untitled" when blank and the summary trimmed.
///   * The header counts only the CONTRIBUTING Items (those with a summary),
///     pluralised, so the count matches the bullets shown.
///   * When no Item has a summary the result is `null` (the hub shows its empty
///     state — there is nothing to aggregate yet).
String? composeAggregatedSummary(List<RecordingItem> recordings) {
  final contributing = <RecordingItem>[];
  for (final item in recordings) {
    final summary = item.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      contributing.add(item);
    }
  }

  if (contributing.isEmpty) return null;

  final count = contributing.length;
  final header = count == 1 ? '1 recording' : '$count recordings';

  final lines = <String>[header, ''];
  for (final item in contributing) {
    final title = item.title.trim().isEmpty ? 'Untitled' : item.title.trim();
    final summary = item.summary!.trim();
    lines.add('• $title: $summary');
  }

  return lines.join('\n');
}

/// Sparse-sync null-wipe guard for the Matome `aggregatedSummary`, mirroring
/// `inbox_sync.dart` `mergeText` (the recording-level B3 data-loss guard).
///
/// The Matome is its own synced unit (ADR-0003) and `aggregatedSummary` syncs
/// as its own reconcilable field. A sparse Core payload — one that omits or
/// nulls the aggregate even though a good local value exists — must NEVER erase
/// it. Returns [Value.absent] when [incoming] is null/blank so a partial UPDATE
/// leaves the column untouched (the existing local value survives); otherwise a
/// [Value] of the trimmed incoming text.
///
/// No Matome Core sync path exists yet — this is provided + unit-tested now so
/// the W5 matome-sync wave consumes it instead of re-deriving the guard.
Value<String?> mergeAggregatedSummary(String? incoming) {
  final trimmed = incoming?.trim();
  if (trimmed == null || trimmed.isEmpty) return const Value.absent();
  return Value(trimmed);
}

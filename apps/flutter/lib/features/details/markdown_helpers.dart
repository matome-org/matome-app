/// Pure markdown-editing + dirty-tracking helpers for the Details screen (S2).
///
/// Ported faithfully from apps/mobile Views/Details:
///   * [applyInsertMarkdown] mirrors the `insertMarkdown` closure in Details.tsx
///     (see __tests__/unit/insertMarkdown.unit.test.ts).
///   * [computeIsDirty] / [DirtyTracker] mirror the `isDirty` logic in
///     DetailsContainer.tsx (see __tests__/unit/isDirty.unit.test.ts).
///
/// These are deliberately UI-free so the exact RN test cases can be replayed
/// 1:1 in Dart.
library;

/// A text selection range — the analogue of RN's `{ start, end }`.
class TextSelectionRange {
  const TextSelectionRange(this.start, this.end);

  final int start;
  final int end;
}

/// Wraps/prepends [prefix] (+ optional [suffix]) around the selected slice of
/// [text], matching the RN body exactly:
///
/// ```
/// const before   = text.slice(0, start);
/// const selected = text.slice(start, end);
/// const after    = text.slice(end);
/// return before + prefix + selected + suffix + after;
/// ```
///
/// Slicing semantics mirror JS `String.prototype.slice`: indices are clamped to
/// `[0, length]` and an `end` past the string length is treated as the end. The
/// helper does NOT guard against already-applied markers (no idempotency) — it
/// wraps unconditionally, like the RN original.
///
/// String indexing is by UTF-16 code unit (same as JS), so the emoji edge case
/// in the RN suite (`Hello 🌍 world`, selection 9..14) lands identically.
String applyInsertMarkdown(
  String text,
  TextSelectionRange selection,
  String prefix, [
  String suffix = '',
]) {
  final length = text.length;
  final start = selection.start.clamp(0, length);
  final end = selection.end.clamp(start, length);

  final before = text.substring(0, start);
  final selected = text.substring(start, end);
  final after = text.substring(end);
  return before + prefix + selected + suffix + after;
}

/// `isDirty = transcript !== savedText` — the plain reference comparison from
/// DetailsContainer.tsx.
bool computeIsDirty(String transcript, String savedText) =>
    transcript != savedText;

/// Mirrors the `savedTextRef` mutation sequencing (initial load / save /
/// discard) the RN container relies on, ported from
/// __tests__/unit/isDirty.unit.test.ts.
class DirtyTracker {
  DirtyTracker(String initialText)
      : _savedText = initialText,
        _transcript = initialText;

  String _savedText;
  String _transcript;

  String get transcript => _transcript;

  /// Current dirty state: the live transcript differs from the last saved text.
  bool get isDirty => _transcript != _savedText;

  /// User edited the transcript (does not touch the saved baseline).
  void setTranscript(String text) => _transcript = text;

  /// Persist succeeded — advance the saved baseline to the current transcript.
  void save() => _savedText = _transcript;

  /// Discard edits, reverting both the transcript and the saved baseline to
  /// [revertTo] (the W-02 fix: reset the ref on discard so the leave-guard does
  /// not re-fire while navigating away).
  void discard(String revertTo) {
    _savedText = revertTo;
    _transcript = revertTo;
  }
}

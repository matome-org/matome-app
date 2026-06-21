/// Pure dirty-tracking helpers for the file-detail Notes editor.
///
/// Ported faithfully from apps/mobile Views/Details:
///   * [computeIsDirty] / [DirtyTracker] mirror the `isDirty` logic in
///     DetailsContainer.tsx (see __tests__/unit/isDirty.unit.test.ts).
///
/// These are deliberately UI-free so the exact RN test cases can be replayed
/// 1:1 in Dart.
///
/// NOTE: the markdown insert helper (`applyInsertMarkdown`) that once lived here
/// was removed with the retired details_screen toolbar — the new file-detail
/// Notes editor is a plain text field with no markdown toolbar (the gap is
/// pinned by file_detail_audio_test: `toolbar-B` must NOT render), so the helper
/// had no remaining caller.
library;

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

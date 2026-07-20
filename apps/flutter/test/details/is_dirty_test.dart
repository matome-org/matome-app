import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/details/markdown_helpers.dart';

/// 1:1 port of apps/mobile __tests__/unit/isDirty.unit.test.ts.
void main() {
  group('isDirty — comparison logic', () {
    // Initial load
    test(
      'false when transcript equals savedText on initial load (content)',
      () {
        const initial = 'Meeting notes from standup';
        expect(computeIsDirty(initial, initial), isFalse);
      },
    );
    test('false when both transcript and savedText are empty strings', () {
      expect(computeIsDirty('', ''), isFalse);
    });

    // After user edits
    test('true when user appends a character', () {
      expect(computeIsDirty('Hello!', 'Hello'), isTrue);
    });
    test('true when user deletes a character', () {
      expect(computeIsDirty('Hello worl', 'Hello world'), isTrue);
    });
    test('true when user replaces all content', () {
      expect(computeIsDirty('Completely different', 'Original text'), isTrue);
    });
    test('true when user clears all content (empty vs saved)', () {
      expect(computeIsDirty('', 'Some notes'), isTrue);
    });

    // After save
    test(
      'false immediately after savedText is updated to match transcript',
      () {
        const transcript = 'Updated meeting notes';
        expect(computeIsDirty(transcript, transcript), isFalse);
      },
    );
    test('true again if user edits after saving', () {
      expect(
        computeIsDirty('Saved content — added more', 'Saved content'),
        isTrue,
      );
    });

    // Whitespace edge cases
    test('true when the only change is a trailing space', () {
      expect(computeIsDirty('Hello ', 'Hello'), isTrue);
    });
    test('true when the only change is a newline character', () {
      expect(computeIsDirty('Hello\n', 'Hello'), isTrue);
    });
    test('false for identical strings with internal whitespace', () {
      const text = 'Line one\n\nLine two\n  indented';
      expect(computeIsDirty(text, text), isFalse);
    });

    // Markdown content
    test('true when markdown markers are added', () {
      expect(computeIsDirty('**plain text**', 'plain text'), isTrue);
    });
    test('false when markdown content is identical', () {
      const md = '# Heading\n\n- Item one\n- Item two\n\n**bold** and *italic*';
      expect(computeIsDirty(md, md), isFalse);
    });
  });

  group('isDirty — savedText mutation sequences', () {
    test('starts clean on initial load', () {
      final tracker = DirtyTracker('Initial content');
      expect(tracker.isDirty, isFalse);
    });
    test('becomes dirty after user edits', () {
      final tracker = DirtyTracker('Initial content');
      tracker.setTranscript('Initial content — edited');
      expect(tracker.isDirty, isTrue);
    });
    test('becomes clean after a successful save', () {
      final tracker = DirtyTracker('Initial');
      tracker.setTranscript('Initial — edited');
      expect(tracker.isDirty, isTrue);
      tracker.save();
      expect(tracker.isDirty, isFalse);
    });
    test('stays clean on multiple saves without edits in between', () {
      final tracker = DirtyTracker('Some notes');
      tracker.save();
      tracker.save();
      expect(tracker.isDirty, isFalse);
    });
    test('becomes dirty again after editing post-save', () {
      final tracker = DirtyTracker('Initial');
      tracker.save();
      tracker.setTranscript('Initial — more notes');
      expect(tracker.isDirty, isTrue);
    });
    test(
      'becomes clean after discarding edits and reverting to saved text',
      () {
        final tracker = DirtyTracker('Saved text');
        tracker.setTranscript('Edited text');
        expect(tracker.isDirty, isTrue);
        tracker.discard('Saved text');
        expect(tracker.isDirty, isFalse);
      },
    );
    test('reflects dirty state through save → edit → save cycle', () {
      final tracker = DirtyTracker('');
      tracker.setTranscript('First draft');
      expect(tracker.isDirty, isTrue);
      tracker.save();
      expect(tracker.isDirty, isFalse);
      tracker.setTranscript('First draft — revised');
      expect(tracker.isDirty, isTrue);
      tracker.save();
      expect(tracker.isDirty, isFalse);
    });
    test('handles empty-to-empty transitions as clean', () {
      final tracker = DirtyTracker('');
      expect(tracker.isDirty, isFalse);
    });
    test('clean when user types then deletes back to original content', () {
      final tracker = DirtyTracker('Original');
      tracker.setTranscript('Original extra');
      expect(tracker.isDirty, isTrue);
      tracker.setTranscript('Original');
      expect(tracker.isDirty, isFalse);
    });
  });
}

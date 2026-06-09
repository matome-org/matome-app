import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/details/markdown_helpers.dart';

/// 1:1 port of apps/mobile __tests__/unit/insertMarkdown.unit.test.ts.
/// Each `it(...)` below maps to the RN case with identical inputs/outputs so
/// the Flutter helper has provable parity with the RN closure.
String _apply(String text, int start, int end, String prefix,
        [String suffix = '']) =>
    applyInsertMarkdown(text, TextSelectionRange(start, end), prefix, suffix);

void main() {
  group('insertMarkdown — Bold (**)', () {
    test('wraps selected text with ** markers', () {
      expect(_apply('Hello world', 6, 11, '**', '**'), 'Hello **world**');
    });
    test('inserts ** at cursor position when no text is selected', () {
      expect(_apply('Hello world', 5, 5, '**', '**'), 'Hello**** world');
    });
    test('wraps text selected from the very start of the string', () {
      expect(_apply('Hello world', 0, 5, '**', '**'), '**Hello** world');
    });
    test('wraps text selected to the very end of the string', () {
      expect(_apply('Hello world', 6, 11, '**', '**'), 'Hello **world**');
    });
    test('wraps the entire string when selection spans all of it', () {
      expect(_apply('Hello', 0, 5, '**', '**'), '**Hello**');
    });
    test('handles empty transcript with cursor at position 0', () {
      expect(_apply('', 0, 0, '**', '**'), '****');
    });
    test('double-wraps already-bolded text (no idempotency guard)', () {
      expect(_apply('**already**', 0, 11, '**', '**'), '****already****');
    });
  });

  group('insertMarkdown — Italic (*)', () {
    test('wraps selected text with * markers', () {
      expect(_apply('Hello world', 6, 11, '*', '*'), 'Hello *world*');
    });
    test('inserts * at cursor when there is no selection', () {
      expect(_apply('Hello world', 5, 5, '*', '*'), 'Hello** world');
    });
    test('handles empty transcript', () {
      expect(_apply('', 0, 0, '*', '*'), '**');
    });
  });

  group('insertMarkdown — Heading (\\n# )', () {
    test('inserts heading prefix at cursor with no selection', () {
      expect(_apply('My note', 7, 7, '\n# '), 'My note\n# ');
    });
    test('prepends heading prefix before selected text leaving it intact', () {
      expect(_apply('Title here', 0, 5, '\n# '), '\n# Title here');
    });
    test('inserts heading at position 0 of an empty document', () {
      expect(_apply('', 0, 0, '\n# '), '\n# ');
    });
    test('inserts correctly in the middle of multi-line text', () {
      expect(_apply('Line one\nLine two', 9, 9, '\n# '), 'Line one\n\n# Line two');
    });
  });

  group('insertMarkdown — Bullet list (\\n- )', () {
    test('inserts list marker at cursor position', () {
      expect(_apply('My note', 7, 7, '\n- '), 'My note\n- ');
    });
    test('prepends list marker before a selected word', () {
      expect(_apply('Item one', 0, 4, '\n- '), '\n- Item one');
    });
    test('works on empty transcript', () {
      expect(_apply('', 0, 0, '\n- '), '\n- ');
    });
  });

  group('insertMarkdown — Checkbox (\\n- [ ] )', () {
    test('inserts checkbox marker at cursor position', () {
      expect(_apply('Todo list', 9, 9, '\n- [ ] '), 'Todo list\n- [ ] ');
    });
    test('prepends checkbox marker before selected text', () {
      expect(_apply('Buy milk', 0, 8, '\n- [ ] '), '\n- [ ] Buy milk');
    });
    test('works on empty transcript', () {
      expect(_apply('', 0, 0, '\n- [ ] '), '\n- [ ] ');
    });
  });

  group('insertMarkdown — edge cases', () {
    test('handles a zero-width selection (start === end) in the middle', () {
      expect(_apply('abc', 1, 1, '**', '**'), 'a****bc');
    });
    test('handles unicode emoji without corrupting surrounding text', () {
      const text = 'Hello 🌍 world';
      expect(_apply(text, 9, 14, '**', '**'), 'Hello 🌍 **world**');
    });
    test('handles multi-line text — selection across a newline', () {
      const text = 'Line one\nLine two\nLine three';
      expect(_apply(text, 9, 17, '**', '**'),
          'Line one\n**Line two**\nLine three');
    });
    test('clamps gracefully when selection end overshoots string length', () {
      expect(_apply('Hi', 0, 999, '**', '**'), '**Hi**');
    });
    test('handles whitespace-only transcript', () {
      expect(_apply('   ', 1, 2, '**', '**'), ' ** ** ');
    });
    test('produces correct output for all 5 toolbar actions on same input', () {
      const transcript = 'meeting notes';
      const start = 8;
      const end = 13; // selects "notes"
      final actions = <(String, String, String)>[
        ('**', '**', 'meeting **notes**'),
        ('*', '*', 'meeting *notes*'),
        ('\n# ', '', 'meeting \n# notes'),
        ('\n- ', '', 'meeting \n- notes'),
        ('\n- [ ] ', '', 'meeting \n- [ ] notes'),
      ];
      for (final (prefix, suffix, expected) in actions) {
        expect(_apply(transcript, start, end, prefix, suffix), expected);
      }
    });
  });
}

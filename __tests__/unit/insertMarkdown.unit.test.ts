/**
 * Unit tests for the insertMarkdown helper logic from Details.tsx.
 *
 * The helper is a closure over transcript, selection, and onTranscriptChange.
 * We test the pure string transformation in isolation by recreating
 * the exact function body from the component.
 */

interface Selection {
  start: number;
  end: number;
}

function applyInsertMarkdown(
  transcript: string,
  selection: Selection,
  prefix: string,
  suffix = "",
): string {
  const before = transcript.slice(0, selection.start);
  const selected = transcript.slice(selection.start, selection.end);
  const after = transcript.slice(selection.end);
  return before + prefix + selected + suffix + after;
}

// ─── BOLD (**) ────────────────────────────────────────────────────────────────

describe("insertMarkdown — Bold (**)", () => {
  it("should wrap selected text with ** markers", () => {
    const result = applyInsertMarkdown("Hello world", { start: 6, end: 11 }, "**", "**");
    expect(result).toBe("Hello **world**");
  });

  it("should insert ** at cursor position when no text is selected", () => {
    const result = applyInsertMarkdown("Hello world", { start: 5, end: 5 }, "**", "**");
    expect(result).toBe("Hello**** world");
  });

  it("should wrap text selected from the very start of the string", () => {
    const result = applyInsertMarkdown("Hello world", { start: 0, end: 5 }, "**", "**");
    expect(result).toBe("**Hello** world");
  });

  it("should wrap text selected to the very end of the string", () => {
    const result = applyInsertMarkdown("Hello world", { start: 6, end: 11 }, "**", "**");
    expect(result).toBe("Hello **world**");
  });

  it("should wrap the entire string when selection spans all of it", () => {
    const result = applyInsertMarkdown("Hello", { start: 0, end: 5 }, "**", "**");
    expect(result).toBe("**Hello**");
  });

  it("should handle empty transcript with cursor at position 0", () => {
    const result = applyInsertMarkdown("", { start: 0, end: 0 }, "**", "**");
    expect(result).toBe("****");
  });

  it("should double-wrap already-bolded text (no idempotency guard)", () => {
    // The helper does NOT detect existing markers — it wraps unconditionally.
    // This test documents the current behaviour as a baseline.
    const result = applyInsertMarkdown("**already**", { start: 0, end: 11 }, "**", "**");
    expect(result).toBe("****already****");
  });
});

// ─── ITALIC (*) ───────────────────────────────────────────────────────────────

describe("insertMarkdown — Italic (*)", () => {
  it("should wrap selected text with * markers", () => {
    const result = applyInsertMarkdown("Hello world", { start: 6, end: 11 }, "*", "*");
    expect(result).toBe("Hello *world*");
  });

  it("should insert * at cursor when there is no selection", () => {
    const result = applyInsertMarkdown("Hello world", { start: 5, end: 5 }, "*", "*");
    expect(result).toBe("Hello** world");
  });

  it("should handle empty transcript", () => {
    const result = applyInsertMarkdown("", { start: 0, end: 0 }, "*", "*");
    expect(result).toBe("**");
  });
});

// ─── HEADING (\n# ) ───────────────────────────────────────────────────────────

describe("insertMarkdown — Heading (\\n# )", () => {
  it("should insert heading prefix at cursor with no selection", () => {
    const result = applyInsertMarkdown("My note", { start: 7, end: 7 }, "\n# ");
    expect(result).toBe("My note\n# ");
  });

  it("should prepend heading prefix before selected text leaving it intact", () => {
    const result = applyInsertMarkdown("Title here", { start: 0, end: 5 }, "\n# ");
    expect(result).toBe("\n# Title here");
  });

  it("should insert heading at position 0 of an empty document", () => {
    const result = applyInsertMarkdown("", { start: 0, end: 0 }, "\n# ");
    expect(result).toBe("\n# ");
  });

  it("should insert correctly in the middle of multi-line text", () => {
    const result = applyInsertMarkdown("Line one\nLine two", { start: 9, end: 9 }, "\n# ");
    expect(result).toBe("Line one\n\n# Line two");
  });
});

// ─── BULLET LIST (\n- ) ───────────────────────────────────────────────────────

describe("insertMarkdown — Bullet list (\\n- )", () => {
  it("should insert list marker at cursor position", () => {
    const result = applyInsertMarkdown("My note", { start: 7, end: 7 }, "\n- ");
    expect(result).toBe("My note\n- ");
  });

  it("should prepend list marker before a selected word", () => {
    const result = applyInsertMarkdown("Item one", { start: 0, end: 4 }, "\n- ");
    expect(result).toBe("\n- Item one");
  });

  it("should work on empty transcript", () => {
    const result = applyInsertMarkdown("", { start: 0, end: 0 }, "\n- ");
    expect(result).toBe("\n- ");
  });
});

// ─── CHECKBOX (\n- [ ] ) ──────────────────────────────────────────────────────

describe("insertMarkdown — Checkbox (\\n- [ ] )", () => {
  it("should insert checkbox marker at cursor position", () => {
    const result = applyInsertMarkdown("Todo list", { start: 9, end: 9 }, "\n- [ ] ");
    expect(result).toBe("Todo list\n- [ ] ");
  });

  it("should prepend checkbox marker before selected text", () => {
    const result = applyInsertMarkdown("Buy milk", { start: 0, end: 8 }, "\n- [ ] ");
    expect(result).toBe("\n- [ ] Buy milk");
  });

  it("should work on empty transcript", () => {
    const result = applyInsertMarkdown("", { start: 0, end: 0 }, "\n- [ ] ");
    expect(result).toBe("\n- [ ] ");
  });
});

// ─── EDGE CASES ───────────────────────────────────────────────────────────────

describe("insertMarkdown — edge cases", () => {
  it("should handle a zero-width selection (start === end) in the middle of text", () => {
    const result = applyInsertMarkdown("abc", { start: 1, end: 1 }, "**", "**");
    expect(result).toBe("a****bc");
  });

  it("should handle unicode emoji without corrupting surrounding text", () => {
    const text = "Hello 🌍 world";
    const result = applyInsertMarkdown(text, { start: 10, end: 15 }, "**", "**");
    expect(result).toBe("Hello 🌍 **world**");
  });

  it("should handle multi-line text — selection across a newline", () => {
    const text = "Line one\nLine two\nLine three";
    const result = applyInsertMarkdown(text, { start: 9, end: 17 }, "**", "**");
    expect(result).toBe("Line one\n**Line two**\nLine three");
  });

  it("should clamp gracefully when selection end overshoots string length", () => {
    const result = applyInsertMarkdown("Hi", { start: 0, end: 999 }, "**", "**");
    expect(result).toBe("**Hi**");
  });

  it("should handle whitespace-only transcript", () => {
    const result = applyInsertMarkdown("   ", { start: 1, end: 2 }, "**", "**");
    expect(result).toBe(" ** **");
  });

  it("should produce correct output for all 5 toolbar actions on the same input", () => {
    const transcript = "meeting notes";
    const sel = { start: 8, end: 13 }; // selects "notes"

    const actions: Array<[string, string | undefined, string]> = [
      ["**",       "**",      "meeting **notes**"],
      ["*",        "*",       "meeting *notes*"],
      ["\n# ",     undefined, "meeting \n# notes"],
      ["\n- ",     undefined, "meeting \n- notes"],
      ["\n- [ ] ", undefined, "meeting \n- [ ] notes"],
    ];

    for (const [prefix, suffix, expected] of actions) {
      expect(
        applyInsertMarkdown(transcript, sel, prefix, suffix ?? ""),
      ).toBe(expected);
    }
  });
});

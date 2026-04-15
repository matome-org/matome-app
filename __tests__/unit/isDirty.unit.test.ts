/**
 * Unit tests for isDirty tracking logic from DetailsContainer.tsx.
 *
 * isDirty = transcript !== savedTextRef.current
 *
 * We test the comparison semantics in isolation — no React, no hooks.
 * The ref mutation patterns (initial load, post-save, discard) are each
 * covered as discrete scenarios.
 */

// ─── Pure comparison logic ────────────────────────────────────────────────────

describe("isDirty — comparison logic", () => {
  function computeIsDirty(transcript: string, savedText: string): boolean {
    return transcript !== savedText;
  }

  // ── Initial load

  it("should be false when transcript equals savedTextRef on initial load with content", () => {
    const initialText = "Meeting notes from standup";
    expect(computeIsDirty(initialText, initialText)).toBe(false);
  });

  it("should be false when both transcript and savedTextRef are empty strings", () => {
    expect(computeIsDirty("", "")).toBe(false);
  });

  // ── After user edits

  it("should be true when user appends a character", () => {
    expect(computeIsDirty("Hello!", "Hello")).toBe(true);
  });

  it("should be true when user deletes a character", () => {
    expect(computeIsDirty("Hello worl", "Hello world")).toBe(true);
  });

  it("should be true when user replaces all content", () => {
    expect(computeIsDirty("Completely different", "Original text")).toBe(true);
  });

  it("should be true when user clears all content (empty string vs saved)", () => {
    expect(computeIsDirty("", "Some notes")).toBe(true);
  });

  // ── After save

  it("should be false immediately after savedTextRef is updated to match transcript", () => {
    const transcript = "Updated meeting notes";
    expect(computeIsDirty(transcript, transcript)).toBe(false);
  });

  it("should become true again if user edits after saving", () => {
    expect(computeIsDirty("Saved content — added more", "Saved content")).toBe(true);
  });

  // ── Whitespace edge cases

  it("should be true when the only change is a trailing space", () => {
    expect(computeIsDirty("Hello ", "Hello")).toBe(true);
  });

  it("should be true when the only change is a newline character", () => {
    expect(computeIsDirty("Hello\n", "Hello")).toBe(true);
  });

  it("should be false for identical strings with internal whitespace", () => {
    const text = "Line one\n\nLine two\n  indented";
    expect(computeIsDirty(text, text)).toBe(false);
  });

  // ── Markdown content

  it("should be true when markdown markers are added", () => {
    expect(computeIsDirty("**plain text**", "plain text")).toBe(true);
  });

  it("should be false when markdown content is identical", () => {
    const md = "# Heading\n\n- Item one\n- Item two\n\n**bold** and *italic*";
    expect(computeIsDirty(md, md)).toBe(false);
  });
});

// ─── Ref mutation sequencing ──────────────────────────────────────────────────

describe("isDirty — savedTextRef mutation sequences", () => {
  function createDirtyTracker(initialText: string) {
    const savedTextRef = { current: initialText };
    let transcript = initialText;

    return {
      setTranscript(text: string) {
        transcript = text;
      },
      save() {
        savedTextRef.current = transcript;
      },
      discard(revertTo: string) {
        // W-02 fix: reset ref on discard
        savedTextRef.current = revertTo;
        transcript = revertTo;
      },
      get isDirty() {
        return transcript !== savedTextRef.current;
      },
      get transcript() {
        return transcript;
      },
    };
  }

  it("should start clean on initial load", () => {
    const tracker = createDirtyTracker("Initial content");
    expect(tracker.isDirty).toBe(false);
  });

  it("should become dirty after user edits", () => {
    const tracker = createDirtyTracker("Initial content");
    tracker.setTranscript("Initial content — edited");
    expect(tracker.isDirty).toBe(true);
  });

  it("should become clean after a successful save", () => {
    const tracker = createDirtyTracker("Initial");
    tracker.setTranscript("Initial — edited");
    expect(tracker.isDirty).toBe(true);
    tracker.save();
    expect(tracker.isDirty).toBe(false);
  });

  it("should stay clean on multiple saves without edits in between", () => {
    const tracker = createDirtyTracker("Some notes");
    tracker.save();
    tracker.save();
    expect(tracker.isDirty).toBe(false);
  });

  it("should become dirty again after editing post-save", () => {
    const tracker = createDirtyTracker("Initial");
    tracker.save();
    tracker.setTranscript("Initial — more notes");
    expect(tracker.isDirty).toBe(true);
  });

  it("should become clean after discarding edits and reverting to saved text", () => {
    const tracker = createDirtyTracker("Saved text");
    tracker.setTranscript("Edited text");
    expect(tracker.isDirty).toBe(true);
    tracker.discard("Saved text");
    expect(tracker.isDirty).toBe(false);
  });

  it("should correctly reflect dirty state through save → edit → save cycle", () => {
    const tracker = createDirtyTracker("");

    tracker.setTranscript("First draft");
    expect(tracker.isDirty).toBe(true);

    tracker.save();
    expect(tracker.isDirty).toBe(false);

    tracker.setTranscript("First draft — revised");
    expect(tracker.isDirty).toBe(true);

    tracker.save();
    expect(tracker.isDirty).toBe(false);
  });

  it("should handle empty-to-empty transitions as clean", () => {
    const tracker = createDirtyTracker("");
    expect(tracker.isDirty).toBe(false);
  });

  it("should be clean when user types then deletes back to original content", () => {
    const tracker = createDirtyTracker("Original");
    tracker.setTranscript("Original extra");
    expect(tracker.isDirty).toBe(true);
    tracker.setTranscript("Original");
    expect(tracker.isDirty).toBe(false);
  });
});

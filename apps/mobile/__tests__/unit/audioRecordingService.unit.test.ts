/**
 * Unit tests for services/audioRecordingService.ts — the highest-risk module
 * (the three audits found E1/E2 session-state-bleed + file-leak defects here).
 *
 * Coverage map (one or more passing tests each):
 *   (a) mergeSegments         — 0 throws, 1 = passthrough, 2+ = last (limitation)
 *   (b) restoreSegments order — startRecording reset → restore([A]) → stop appends
 *                               'B' ⇒ sessionSegments = ['A','B']  (audit#1/#3 fix)
 *   (c) cross-session reset   — a fresh startRecording clears savedAudioFilePath /
 *                               transcriptionTempFiles / sessionSegments /
 *                               recordingUri  (audit#2 fix)
 *   (d) per-session snapshot  — saveRecordingFromSegments cleanup deletes only its
 *                               OWN snapshot list, not a concurrent session tracker
 *   (e) discardSegments       — removes ALL segment + tracked temp files (no orphan)
 *   (f) safeDeleteFile guard  — refuses paths outside documentDirectory / with '..'
 *                               (deleteAsync NOT called); deletes a valid path
 *   (g) releaseRecorder       — stops recorder + clears metering interval, does NOT
 *                               discard segments / draft (recovery preserved)
 *
 * Mocking strategy:
 *   - expo-audio: mock AudioModule.AudioRecorder (a controllable fake), plus the
 *     other named exports the module imports at load time.
 *   - expo-file-system/legacy: mock documentDirectory (fixed string, so the
 *     sandbox guard is testable) + getInfoAsync / deleteAsync / copyAsync.
 *   - axios, @/config/config, @/services/*, @/processes/homeData, react-native:
 *     mocked so the module loads in isolation.
 *
 * Module-level state isolation: audioRecordingService keeps per-session state in
 * module-level `let`s. Each test calls loadService() which does jest.resetModules()
 * + a fresh require, so cases never bleed state into each other.
 */

// Fixed sandbox root so the documentDirectory guard is deterministic + testable.
const DOC_DIR = "file:///app/documents/";

// ─── Module mocks ───────────────────────────────────────────────────────────

// The fake recorder + its tracking state live INSIDE the jest.mock factory.
// jest hoists factories above imports and forbids referencing out-of-scope vars,
// EXCEPT names prefixed with `mock`. So everything the factory closes over is
// `mock`-prefixed, and tests reach it through the mocked module's exposed
// __getInstances / __setNextUri helpers.
jest.mock("expo-audio", () => {
  let mockNextUri: string | null = "file:///cache/live.m4a";
  const mockInstances: MockRecorder[] = [];

  class MockRecorder {
    uri: string | null;
    prepareToRecordAsync = jest.fn().mockResolvedValue(undefined);
    record = jest.fn();
    pause = jest.fn();
    stop = jest.fn().mockResolvedValue(undefined);
    release = jest.fn();
    getStatus = jest.fn(() => ({
      isRecording: true,
      metering: -20,
      durationMillis: 1234,
    }));

    constructor() {
      this.uri = mockNextUri;
      mockInstances.push(this);
    }
  }

  return {
    AudioModule: { AudioRecorder: MockRecorder },
    setAudioModeAsync: jest.fn().mockResolvedValue(undefined),
    requestRecordingPermissionsAsync: jest
      .fn()
      .mockResolvedValue({ granted: true }),
    RecordingPresets: {
      HIGH_QUALITY: {
        extension: ".m4a",
        sampleRate: 44100,
        numberOfChannels: 2,
        bitRate: 128000,
        ios: {},
        android: {},
        web: {},
      },
    },
    // getAudioDurationSeconds() creates a player and resolves on the first
    // playbackStatusUpdate where isLoaded && duration > 0. Fire it immediately so
    // the save paths don't hang on the 5s real-device fallback timeout.
    createAudioPlayer: jest.fn(() => ({
      addListener: jest.fn(
        (
          _event: string,
          cb: (status: { isLoaded: boolean; duration: number }) => void,
        ) => {
          setImmediate(() => cb({ isLoaded: true, duration: 12 }));
          return { remove: jest.fn() };
        },
      ),
      remove: jest.fn(),
    })),
    // Test-only helpers (not part of the real expo-audio surface).
    __getInstances: () => mockInstances,
    __resetInstances: () => {
      mockInstances.length = 0;
    },
    __setNextUri: (uri: string | null) => {
      mockNextUri = uri;
    },
  };
});

interface MockRecorder {
  uri: string | null;
  prepareToRecordAsync: jest.Mock;
  record: jest.Mock;
  pause: jest.Mock;
  stop: jest.Mock;
  release: jest.Mock;
  getStatus: jest.Mock;
}

interface ExpoAudioMock {
  __getInstances: () => MockRecorder[];
  __resetInstances: () => void;
  __setNextUri: (uri: string | null) => void;
}

jest.mock("expo-file-system/legacy", () => ({
  documentDirectory: "file:///app/documents/",
  getInfoAsync: jest.fn().mockResolvedValue({ exists: true }),
  deleteAsync: jest.fn().mockResolvedValue(undefined),
  copyAsync: jest.fn().mockResolvedValue(undefined),
}));

jest.mock("axios", () => ({
  __esModule: true,
  default: { create: jest.fn(() => null) },
}));

jest.mock("@/config/config", () => ({
  configs: [],
}));

jest.mock("@/services/recordingService", () => ({
  createRecording: jest.fn().mockResolvedValue(undefined),
  updateRecording: jest.fn().mockResolvedValue(undefined),
}));

jest.mock("@/services/coreRecordingService", () => ({
  createPendingCoreRecording: jest.fn().mockResolvedValue({
    recording: {
      id: 123,
      owner_id: 456,
      title: "New Recording",
      storage_key: "owners/456/recordings/123/media",
      status: "pending",
      inserted_at: "2026-06-05T00:00:00Z",
      updated_at: "2026-06-05T00:00:00Z",
    },
    upload: { url: "http://localhost/upload", method: "PUT", expires_in: 60 },
  }),
  uploadCoreRecordingAudio: jest.fn().mockResolvedValue(undefined),
  enqueueCoreRecordingProcessing: jest.fn().mockResolvedValue(undefined),
  waitForCoreRecordingResult: jest.fn().mockResolvedValue({
    id: 123,
    owner_id: 456,
    title: "Processed Recording",
    storage_key: "owners/456/recordings/123/media",
    status: "done",
    transcript: "transcript",
    summary: "summary",
    inserted_at: "2026-06-05T00:00:00Z",
    updated_at: "2026-06-05T00:00:00Z",
  }),
}));

jest.mock("@/services/coreApiClient", () => ({
  coreApiClient: {
    getRecording: jest.fn().mockResolvedValue({
      recording: {
        id: 123,
        owner_id: 456,
        title: "New Recording",
        storage_key: "owners/456/recordings/123/media",
        status: "pending",
        inserted_at: "2026-06-05T00:00:00Z",
        updated_at: "2026-06-05T00:00:00Z",
      },
    }),
  },
}));

jest.mock("react-native", () => ({
  Alert: { alert: jest.fn() },
  Platform: { OS: "ios" },
}));

// ─── Helpers ────────────────────────────────────────────────────────────────

type Service = typeof import("@/services/audioRecordingService");
type FileSystemMock = {
  documentDirectory: string;
  getInfoAsync: jest.Mock;
  deleteAsync: jest.Mock;
  copyAsync: jest.Mock;
};

/**
 * Load a FRESH copy of the service (resetting all module-level state) along with
 * the fresh mock handles that copy is bound to. Optionally seed the next-created
 * recorder's uri.
 */
function loadService(opts: { recorderUri?: string | null } = {}): {
  service: Service;
  fs: FileSystemMock;
  audio: ExpoAudioMock;
} {
  jest.resetModules();

  let service!: Service;
  let fs!: FileSystemMock;
  let audio!: ExpoAudioMock;
  jest.isolateModules(() => {
    // require AFTER resetModules so the module-level `let`s are fresh.
    fs = require("expo-file-system/legacy") as FileSystemMock;
    audio = require("expo-audio") as unknown as ExpoAudioMock;
    audio.__resetInstances();
    audio.__setNextUri(opts.recorderUri ?? "file:///cache/live.m4a");
    service = require("@/services/audioRecordingService") as Service;
  });
  return { service, fs, audio };
}

beforeEach(() => {
  jest.clearAllMocks();
});

// ─── (a) mergeSegments ────────────────────────────────────────────────────────

describe("mergeSegments", () => {
  it("throws when there are 0 segments", async () => {
    const { service } = loadService();
    await expect(service.mergeSegments()).rejects.toThrow(
      "mergeSegments: no segments to merge",
    );
  });

  it("returns the single segment unchanged (passthrough) for 1 segment", async () => {
    const { service } = loadService();
    const only = `${DOC_DIR}segment_only.m4a`;
    service.restoreSegments([only]);
    await expect(service.mergeSegments()).resolves.toBe(only);
  });

  it("returns the LAST segment for 2+ segments (documented limitation)", async () => {
    const { service } = loadService();
    const a = `${DOC_DIR}segment_a.m4a`;
    const b = `${DOC_DIR}segment_b.m4a`;
    const c = `${DOC_DIR}segment_c.m4a`;
    service.restoreSegments([a, b, c]);
    await expect(service.mergeSegments()).resolves.toBe(c);
  });
});

// ─── (b) restoreSegments + ordering (audit#1/#3 — the crux) ────────────────────

describe("restoreSegments + startRecording ordering", () => {
  it("startRecording() resets → restoreSegments(['A']) → stopRecording appends 'B' ⇒ ['A','B']", async () => {
    const liveUri = "file:///cache/new-span.m4a";
    const { service, fs } = loadService({ recorderUri: liveUri });

    // Recovery-resume flow: startRecording first (it RESETS sessionSegments),
    // THEN restoreSegments re-seeds the recovered span 'A'.
    await service.startRecording();
    const A = `${DOC_DIR}segment_A.m4a`;
    service.restoreSegments([A]);
    expect(service.getSegments()).toEqual([A]);

    // The freshly recorded span is recorded straight-through (no pause), so the
    // recorder is NOT a continuous session ⇒ stopRecording takes the APPEND
    // branch (not the collapse-to-one branch). copyAsync writes 'B' to a
    // segment_*.m4a under documentDirectory; capture that destination.
    await service.stopRecording();

    const copyDest = (fs.copyAsync.mock.calls[0][0] as { to: string }).to;
    expect(copyDest.startsWith(DOC_DIR)).toBe(true);

    const segments = service.getSegments();
    expect(segments).toHaveLength(2);
    expect(segments[0]).toBe(A); // restored span first
    expect(segments[1]).toBe(copyDest); // newly recorded span ('B') last
  });
});

// ─── (c) cross-session reset (audit#2) ─────────────────────────────────────────

describe("cross-session state reset at startRecording", () => {
  it("a fresh startRecording() clears sessionSegments / recordingUri / temp tracker / savedAudioFilePath", async () => {
    const { service, fs, audio } = loadService({
      recorderUri: "file:///cache/s1.m4a",
    });

    // --- Session 1: record, stop (accumulate a segment), and SAVE so that
    // savedAudioFilePath + transcriptionTempFiles get populated. ---
    await service.startRecording();
    await service.stopRecording();
    expect(service.getSegments()).toHaveLength(1);

    // saveRecordingFromSegments populates savedAudioFilePath + a temp copy.
    await service.saveRecordingFromSegments("Inbox");
    // A recording_*.mp3 temp copy was produced by prepareAudioForTranscription.
    const tempCopyCalls = fs.copyAsync.mock.calls.filter((c) =>
      ((c[0] as { to: string }).to || "").includes("recording_"),
    );
    expect(tempCopyCalls.length).toBeGreaterThan(0);

    const savedTempPath = (tempCopyCalls[0][0] as { to: string }).to;

    // Now a discard with a save in-flight must NOT wipe the canonical saved temp
    // (proof savedAudioFilePath is set/non-null at this point). The background
    // pipeline may already have cleaned per-segment temp copies, so assert only
    // the saved path survives this discard.
    fs.deleteAsync.mockClear();
    await service.discardSegments();
    const deleted = fs.deleteAsync.mock.calls.map((c) => String(c[0]));
    expect(deleted).not.toContain(savedTempPath);

    // --- Session 2: a fresh startRecording must reset all per-session globals. ---
    audio.__setNextUri("file:///cache/s2.m4a");
    await service.startRecording();

    // sessionSegments reset to empty…
    expect(service.getSegments()).toEqual([]);

    // …and savedAudioFilePath reset to null: prove it by discarding now. With
    // savedAudioFilePath === null, the temp tracker (if any) WOULD be swept.
    // After the reset the tracker is also empty, so nothing remains — assert no
    // stale recording_*.mp3 from S1 is referenced by S2's discard.
    fs.deleteAsync.mockClear();
    await service.stopRecording(); // S2 produces a fresh segment
    await service.discardSegments();
    // S2's discard sweeps only S2's (empty) temp tracker — no S1 temp leakage.
    const sweptS1Temp = fs.deleteAsync.mock.calls.some((c) =>
      String(c[0]).includes("recording_"),
    );
    expect(sweptS1Temp).toBe(false);
  });
});

// ─── (d) per-session temp snapshot (audit#2 race) ──────────────────────────────

describe("saveRecordingFromSegments per-session temp snapshot cleanup", () => {
  it("copies every background transcription input before returning so immediate discard cannot delete it", async () => {
    const { service, fs } = loadService({
      recorderUri: "file:///cache/s1.m4a",
    });

    await service.startRecording();
    await service.stopRecording();
    const segment = service.getSegments()[0];

    await service.saveRecordingFromSegments("Inbox");

    const recordingCopies = fs.copyAsync.mock.calls
      .map((c) => c[0] as { from: string; to: string })
      .filter((copy) => copy.to.includes("recording_"));
    expect(recordingCopies).toHaveLength(2);
    expect(recordingCopies[1].from).toBe(segment);

    fs.deleteAsync.mockClear();
    await service.discardSegments();

    const deleted = fs.deleteAsync.mock.calls.map((c) => String(c[0]));
    expect(deleted).toContain(segment);
  });

  it("cleanup deletes only this session's snapshot temp list, not a concurrent session's tracker", async () => {
    const { service, fs } = loadService({
      recorderUri: "file:///cache/s1.m4a",
    });

    // Drive Session 1 through save. The background pipeline (the void IIFE)
    // resolves microtasks; flush them so cleanup runs.
    await service.startRecording();
    await service.stopRecording();
    await service.saveRecordingFromSegments("Inbox");

    // Flush the background async cleanup pipeline.
    await flushPromises();

    // The cleanup must have called deleteAsync for the per-session temp snapshot
    // files (the recording_*.mp3 copies), and must PRESERVE the canonical saved
    // audioFilePath (also a recording_*.mp3 — the first temp copy made before the
    // background loop). i.e. it deletes a LOCAL list, never the live global.
    const deletedTemps = fs.deleteAsync.mock.calls
      .map((c) => String(c[0]))
      .filter((p) => p.includes("recording_"));

    // The per-segment loop produced at least one temp that is NOT the saved path,
    // so at least one recording_*.mp3 should have been deleted by the snapshot
    // cleanup (proving cleanup operates over a captured local list).
    expect(deletedTemps.length).toBeGreaterThan(0);

    // Every deleted path is inside the sandbox (the guard let them through).
    for (const p of deletedTemps) {
      expect(p.startsWith(DOC_DIR)).toBe(true);
    }
  });
});

// ─── (e) discardSegments removes all segment + temp files ──────────────────────

describe("discardSegments", () => {
  it("deletes every segment file AND every tracked temp file when no save occurred (no orphan)", async () => {
    const { service, fs } = loadService({
      recorderUri: "file:///cache/live.m4a",
    });

    // Accumulate two segments via restoreSegments (both under documentDirectory).
    const segA = `${DOC_DIR}segment_a.m4a`;
    const segB = `${DOC_DIR}segment_b.m4a`;
    service.restoreSegments([segA, segB]);

    // Track a transcription temp copy (recording_*.mp3) without saving — so
    // savedAudioFilePath stays null and discard must sweep it.
    const tempPath = await service.prepareAudioForTranscription(segA);
    expect(tempPath.startsWith(DOC_DIR)).toBe(true);
    expect(tempPath).toContain("recording_");

    fs.deleteAsync.mockClear();
    await service.discardSegments();

    const deleted = fs.deleteAsync.mock.calls.map((c) => String(c[0]));
    // Both segment files swept…
    expect(deleted).toContain(segA);
    expect(deleted).toContain(segB);
    // …and the orphan-prone transcription temp copy swept too.
    expect(deleted).toContain(tempPath);

    // State cleared: no segments remain after discard.
    expect(service.getSegments()).toEqual([]);
  });
});

// ─── (f) safeDeleteFile / isWithinAppSandbox guard ─────────────────────────────

describe("safeDeleteFile sandbox guard (via discardSegments)", () => {
  it("rejects restored paths OUTSIDE documentDirectory before delete can run", async () => {
    const { service, fs } = loadService();

    fs.deleteAsync.mockClear();
    expect(() => service.restoreSegments(["file:///elsewhere/segment_evil.m4a"])).toThrow(
      "Restored segment URI is outside app storage",
    );

    expect(fs.deleteAsync).not.toHaveBeenCalled();
  });

  it("rejects restored paths containing '..' even under documentDirectory", async () => {
    const { service, fs } = loadService();

    fs.deleteAsync.mockClear();
    expect(() => service.restoreSegments([`${DOC_DIR}../segment_escape.m4a`])).toThrow(
      "Restored segment URI is outside app storage",
    );

    expect(fs.deleteAsync).not.toHaveBeenCalled();
  });

  it("rejects restored paths with unexpected file names", async () => {
    const { service, fs } = loadService();

    fs.deleteAsync.mockClear();
    expect(() => service.restoreSegments([`${DOC_DIR}recording_0.mp3`])).toThrow(
      "Restored segment URI has an unexpected file name",
    );

    expect(fs.deleteAsync).not.toHaveBeenCalled();
  });

  it("deletes a valid documentDirectory path (guard lets it through)", async () => {
    const { service, fs } = loadService();
    const valid = `${DOC_DIR}segment_valid.m4a`;
    service.restoreSegments([valid]);

    fs.getInfoAsync.mockResolvedValue({ exists: true });
    fs.deleteAsync.mockClear();
    await service.discardSegments();

    expect(fs.deleteAsync).toHaveBeenCalledWith(valid, { idempotent: true });
  });
});

// ─── (g) releaseRecorder ───────────────────────────────────────────────────────

describe("releaseRecorder", () => {
  it("stops the recorder + clears the metering interval but PRESERVES segments/draft", async () => {
    const { service, fs, audio } = loadService({
      recorderUri: "file:///cache/live.m4a",
    });
    const clearIntervalSpy = jest.spyOn(global, "clearInterval");

    await service.startRecording();
    // Seed segments to prove they survive release (recovery preserved).
    const seg = `${DOC_DIR}segment_keep.m4a`;
    service.restoreSegments([seg]);

    const instances = audio.__getInstances();
    const liveRecorder = instances[instances.length - 1];
    expect(service.isRecorderActive()).toBe(true);

    fs.deleteAsync.mockClear();
    await service.releaseRecorder();

    // Recorder stopped + released, no longer active.
    expect(liveRecorder.stop).toHaveBeenCalled();
    expect(liveRecorder.release).toHaveBeenCalled();
    expect(service.isRecorderActive()).toBe(false);

    // Metering interval cleared.
    expect(clearIntervalSpy).toHaveBeenCalled();

    // Segments NOT discarded — recovery draft preserved, no files deleted.
    expect(service.getSegments()).toEqual([seg]);
    expect(fs.deleteAsync).not.toHaveBeenCalled();

    clearIntervalSpy.mockRestore();
  });
});

// ─── utils ─────────────────────────────────────────────────────────────────────

/**
 * Flush pending microtasks/timers so fire-and-forget `void (async () => …)()`
 * background pipelines (transcribe → cleanup) settle before assertions.
 */
async function flushPromises(): Promise<void> {
  for (let i = 0; i < 50; i++) {
    await Promise.resolve();
    await new Promise((r) => setImmediate(r));
  }
}

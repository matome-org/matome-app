/**
 * Integration tests for app/recording.tsx — the recording screen state machine.
 *
 * Covered behaviors:
 *   1. Phase state machine: initial idle; record → startRecording + phase=recording.
 *   2. Pause → draftRecordingService.saveDraft called + phase=paused.
 *   3. Resume (live) → resumeRecording + phase=recording.
 *   4. draft_prompt: launched with hasDraft=1 (mock useLocalSearchParams) renders
 *      Resume + Discard affordances.
 *   5. AUDIT#3 FIX: recovered-draft Resume → record path calls restoreSegments with
 *      the recovered spans AFTER startRecording, on the handleStart path when
 *      segmentsRef is non-empty.
 *   6. Finish → router.replace('/(tabs)/inbox/${id}').
 *   7. Discard (draft_prompt) → deleteDraft + discardSegments.
 *
 * Render approach: FULL RTL render. recording.tsx itself does NOT import
 * react-native-reanimated (the waveform is plain <View> bars), so the
 * "worklets not initialized" hazard does not apply here. We still mock all the
 * native-backed service modules (audioRecordingService, draftRecordingService),
 * expo-router, expo-audio, react-i18next, @ui-kitten/components and
 * @expo/vector-icons so nothing pulls a native module at import time.
 *
 * The primary record/pause/resume button is a <Pressable> with no text or
 * testID. We reach it via UNSAFE_getAllByType(Pressable) and select it by the
 * onPress handler that is wired for the current phase.
 *
 * Run: npx jest __tests__/integration/recording.integration.test.tsx
 */

import React from "react";
import {
  render,
  act,
  fireEvent,
  waitFor,
  screen,
} from "@testing-library/react-native";

// ─── Module mocks ─────────────────────────────────────────────────────────────

jest.mock("expo-router", () => ({
  useRouter: jest.fn(),
  useLocalSearchParams: jest.fn(),
}));

jest.mock("@/services/audioRecordingService", () => ({
  cancelRecording: jest.fn().mockResolvedValue(undefined),
  discardSegments: jest.fn().mockResolvedValue(undefined),
  formatDuration: jest.fn((s: number) => `${s}s`),
  getRecordingDuration: jest.fn(() => 0),
  getRecordingMetering: jest.fn(() => undefined),
  isRecorderActive: jest.fn(() => true),
  pauseRecording: jest.fn().mockResolvedValue("file:///snap.m4a"),
  releaseRecorder: jest.fn().mockResolvedValue(undefined),
  restoreSegments: jest.fn(),
  resumeRecording: jest.fn().mockResolvedValue(undefined),
  saveRecordingFromSegments: jest.fn().mockResolvedValue("rec-999"),
  startRecording: jest.fn().mockResolvedValue(undefined),
  stopRecording: jest.fn().mockResolvedValue("file:///final.m4a"),
}));

jest.mock("@/services/draftRecordingService", () => ({
  deleteDraft: jest.fn().mockResolvedValue(undefined),
  loadDraft: jest.fn().mockResolvedValue(null),
  saveDraft: jest.fn().mockResolvedValue(undefined),
}));

jest.mock("@/stores/recordingsStore", () => ({
  useRecordingsStore: (selector: (s: { triggerRefresh: () => void }) => unknown) =>
    selector({ triggerRefresh: jest.fn() }),
}));

jest.mock("react-native-safe-area-context", () => ({
  useSafeAreaInsets: () => ({ top: 0, bottom: 0, left: 0, right: 0 }),
}));

jest.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => key,
    i18n: { language: "en" },
  }),
}));

jest.mock("@ui-kitten/components", () => {
  const { Text } = require("react-native");
  return {
    Text,
    useTheme: () =>
      new Proxy(
        {},
        {
          get: (_t, prop: string) => `#${String(prop)}`,
        },
      ),
  };
});

jest.mock("@expo/vector-icons", () => ({
  Ionicons: "Ionicons",
}));

// ─── Imports under test ───────────────────────────────────────────────────────

import RecordingScreen from "../../app/recording";
import * as audio from "@/services/audioRecordingService";
import * as draft from "@/services/draftRecordingService";
import { useRouter, useLocalSearchParams } from "expo-router";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function setupRouter() {
  const routerMock = {
    replace: jest.fn(),
    push: jest.fn(),
    back: jest.fn(),
  };
  (useRouter as jest.Mock).mockReturnValue(routerMock);
  return routerMock;
}

/**
 * The primary record/pause/resume button has no text or testID. It is the
 * pressable whose style contains the 200px circular `recordingIndicator`.
 * We locate it by traversing the rendered test-instance tree for the node that
 * has an `onPress` handler and a flattened style with width 200.
 */
function pressPrimaryButton() {
  const matches = screen.UNSAFE_root.findAll((node: { props: Record<string, unknown> }) => {
    if (typeof node.props?.onPress !== "function") return false;
    const style = node.props.style;
    const flat = Array.isArray(style) ? Object.assign({}, ...style) : style;
    return !!flat && flat.width === 200;
  });
  if (matches.length === 0) {
    throw new Error("primary record button not found");
  }
  fireEvent.press(matches[0]);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

describe("RecordingScreen — phase state machine", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (audio.getRecordingDuration as jest.Mock).mockReturnValue(0);
    (audio.getRecordingMetering as jest.Mock).mockReturnValue(undefined);
    (audio.isRecorderActive as jest.Mock).mockReturnValue(true);
    (draft.loadDraft as jest.Mock).mockResolvedValue(null);
  });

  it("starts in idle when launched without a draft", () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({});

    render(<RecordingScreen />);

    expect(screen.getByText("recording.ready")).toBeTruthy();
  });

  it("record tap → startRecording called and phase becomes recording", async () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({});

    render(<RecordingScreen />);

    await act(async () => {
      pressPrimaryButton();
    });

    await waitFor(() => expect(audio.startRecording).toHaveBeenCalledTimes(1));
    // phase=recording → status label is recording.title, pause button appears
    expect(screen.getByText("recording.title")).toBeTruthy();
    expect(screen.getByText("recording.pause")).toBeTruthy();
  });

  it("pause → saveDraft called and phase becomes paused", async () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({});

    render(<RecordingScreen />);

    // idle → recording
    await act(async () => {
      pressPrimaryButton();
    });
    await waitFor(() => expect(audio.startRecording).toHaveBeenCalled());

    // recording → paused (press primary, which is now wired to handlePause)
    await act(async () => {
      pressPrimaryButton();
    });

    await waitFor(() => expect(audio.pauseRecording).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(draft.saveDraft).toHaveBeenCalledTimes(1));
    // phase=paused → status label is recording.paused
    expect(screen.getByText("recording.paused")).toBeTruthy();
  });

  it("resume (live) → resumeRecording called and phase becomes recording", async () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({});

    render(<RecordingScreen />);

    await act(async () => {
      pressPrimaryButton(); // idle → recording
    });
    await waitFor(() => expect(audio.startRecording).toHaveBeenCalled());

    await act(async () => {
      pressPrimaryButton(); // recording → paused
    });
    await waitFor(() => expect(audio.pauseRecording).toHaveBeenCalled());

    await act(async () => {
      pressPrimaryButton(); // paused → resume → recording
    });

    await waitFor(() => expect(audio.resumeRecording).toHaveBeenCalledTimes(1));
    expect(screen.getByText("recording.title")).toBeTruthy();
  });
});

describe("RecordingScreen — draft recovery prompt", () => {
  const DRAFT_SEGMENTS = ["file:///seg-1.m4a", "file:///seg-2.m4a"];

  beforeEach(() => {
    jest.clearAllMocks();
    (audio.getRecordingDuration as jest.Mock).mockReturnValue(0);
    (audio.getRecordingMetering as jest.Mock).mockReturnValue(undefined);
    (audio.isRecorderActive as jest.Mock).mockReturnValue(true);
  });

  it("hasDraft=1 with a stored draft renders Resume + Discard affordances", async () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({ hasDraft: "1" });
    (draft.loadDraft as jest.Mock).mockResolvedValue({
      segments: DRAFT_SEGMENTS,
      durationMs: 12000,
    });

    render(<RecordingScreen />);

    await waitFor(() => expect(draft.loadDraft).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText("recording.draftResume")).toBeTruthy());
    expect(screen.getByText("recording.draftDiscard")).toBeTruthy();
  });

  it("AUDIT#3: recovered-draft Resume → record calls restoreSegments AFTER startRecording with the draft spans", async () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({ hasDraft: "1" });
    (draft.loadDraft as jest.Mock).mockResolvedValue({
      segments: DRAFT_SEGMENTS,
      durationMs: 12000,
    });

    // Track call order: startRecording must precede restoreSegments.
    const order: string[] = [];
    (audio.startRecording as jest.Mock).mockImplementation(async () => {
      order.push("start");
    });
    (audio.restoreSegments as jest.Mock).mockImplementation(() => {
      order.push("restore");
    });

    render(<RecordingScreen />);
    await waitFor(() => expect(screen.getByText("recording.draftResume")).toBeTruthy());

    // Tap "Resume" on the draft prompt → transitions to idle, segmentsRef seeded.
    await act(async () => {
      fireEvent.press(screen.getByText("recording.draftResume"));
    });
    await waitFor(() => expect(screen.getByText("recording.ready")).toBeTruthy());

    // Tap the primary record button → handleStart. Because segmentsRef is
    // non-empty (recovered spans), restoreSegments must be called with them,
    // AFTER startRecording.
    await act(async () => {
      pressPrimaryButton();
    });

    await waitFor(() => expect(audio.startRecording).toHaveBeenCalled());
    await waitFor(() => expect(audio.restoreSegments).toHaveBeenCalledTimes(1));
    expect(audio.restoreSegments).toHaveBeenCalledWith(DRAFT_SEGMENTS);
    // Ordering: startRecording reset module state, restoreSegments re-seeds AFTER.
    expect(order).toEqual(["start", "restore"]);
  });

  it("Discard → deleteDraft + discardSegments called", async () => {
    setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({ hasDraft: "1" });
    (draft.loadDraft as jest.Mock).mockResolvedValue({
      segments: DRAFT_SEGMENTS,
      durationMs: 12000,
    });

    render(<RecordingScreen />);
    await waitFor(() => expect(screen.getByText("recording.draftDiscard")).toBeTruthy());

    await act(async () => {
      fireEvent.press(screen.getByText("recording.draftDiscard"));
    });

    await waitFor(() => expect(audio.discardSegments).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(draft.deleteDraft).toHaveBeenCalledTimes(1));
    // back to fresh idle
    expect(screen.getByText("recording.ready")).toBeTruthy();
  });
});

describe("RecordingScreen — finish navigation", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (audio.getRecordingDuration as jest.Mock).mockReturnValue(0);
    (audio.getRecordingMetering as jest.Mock).mockReturnValue(undefined);
    (audio.isRecorderActive as jest.Mock).mockReturnValue(true);
    (draft.loadDraft as jest.Mock).mockResolvedValue(null);
  });

  it("finish → router.replace('/(tabs)/inbox/${id}')", async () => {
    const routerMock = setupRouter();
    (useLocalSearchParams as jest.Mock).mockReturnValue({});
    (audio.saveRecordingFromSegments as jest.Mock).mockResolvedValue("rec-999");

    render(<RecordingScreen />);

    // idle → recording so the Finish button is rendered
    await act(async () => {
      pressPrimaryButton();
    });
    await waitFor(() => expect(screen.getByText("recording.finish")).toBeTruthy());

    await act(async () => {
      fireEvent.press(screen.getByText("recording.finish"));
    });

    await waitFor(() =>
      expect(audio.saveRecordingFromSegments).toHaveBeenCalledWith("Inbox"),
    );
    await waitFor(() =>
      expect(routerMock.replace).toHaveBeenCalledWith("/(tabs)/inbox/rec-999"),
    );
  });
});

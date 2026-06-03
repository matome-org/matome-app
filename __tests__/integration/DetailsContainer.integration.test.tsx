/**
 * Integration tests for DetailsContainer.tsx — specifically:
 *   1. beforeRemove navigation guard (the highest-risk feature)
 *   2. handleSave clears dirty state
 *   3. Edit / Preview toggle
 *   4. Initial state on load with and without existing notes
 *
 * Mocking strategy:
 *   - expo-router: mock useRouter, useNavigation, useLocalSearchParams
 *   - recordingService: mock getRecordingById and updateRecording
 *   - summarizeService: mock summarizeText
 *   - expo-audio, expo-file-system/legacy: mock entirely
 *   - react-native Alert: spy on Alert.alert
 *   - react-native-toast-message: mock
 *   - utils/database: mock initDatabase
 *
 * Run: npx jest __tests__/integration/DetailsContainer.integration.test.tsx
 *
 * NOTE: Requires testID props on the FAB and dirty dot in Details.tsx:
 *   <TouchableOpacity testID="fab-save" ...>
 *     {isDirty && <View testID="fab-dirty-dot" ... />}
 *   </TouchableOpacity>
 */

import React from "react";
import {
  render,
  act,
  fireEvent,
  waitFor,
  screen,
} from "@testing-library/react-native";
import { Alert } from "react-native";

// ─── Module mocks ─────────────────────────────────────────────────────────────

jest.mock("expo-router", () => ({
  useRouter: jest.fn(),
  useLocalSearchParams: jest.fn(),
  useNavigation: jest.fn(),
}));

jest.mock("@/services/recordingService", () => ({
  getRecordingById: jest.fn(),
  updateRecording: jest.fn(),
  recordToCard: jest.fn((r: Record<string, unknown>) => ({
    id: r.id,
    title: r.title,
    timestamp: r.timestamp,
    duration: r.duration,
    badge: r.badge,
    notes: r.notes,
    summary: r.summary,
    isProcessing: r.isProcessing === 1,
  })),
}));

jest.mock("@/services/summarizeService", () => ({
  summarizeText: jest.fn(),
}));

jest.mock("@/services/audioRecordingService", () => ({
  retryTranscription: jest.fn(),
}));

jest.mock("@/utils/database", () => ({
  initDatabase: jest.fn().mockResolvedValue(undefined),
}));

jest.mock("expo-audio", () => ({
  createAudioPlayer: jest.fn(() => ({
    addListener: jest.fn(() => ({ remove: jest.fn() })),
    remove: jest.fn(),
    isLoaded: false,
    playing: false,
    currentTime: 0,
    duration: 0,
    pause: jest.fn(),
    play: jest.fn(),
    seekTo: jest.fn(),
  })),
  setAudioModeAsync: jest.fn().mockResolvedValue(undefined),
}));

jest.mock("expo-file-system/legacy", () => ({
  getInfoAsync: jest.fn().mockResolvedValue({ exists: false }),
  readAsStringAsync: jest.fn().mockResolvedValue(""),
  EncodingType: { Base64: "base64" },
}));

jest.mock("react-native-toast-message", () => ({
  show: jest.fn(),
}));

const mockT = (key: string) => key;

jest.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: mockT,
    i18n: { language: "en" },
  }),
}));

jest.mock("@ui-kitten/components", () => {
  const { View, Text } = require("react-native");
  return {
    Layout: View,
    Text,
    useTheme: () => ({
      "color-primary-500": "#3366FF",
      "color-primary-900": "#000080",
      "color-basic-100": "#FFFFFF",
      "color-basic-200": "#F5F5F5",
      "color-basic-300": "#EEE",
      "color-basic-400": "#CCC",
      "color-basic-500": "#AAA",
      "color-basic-600": "#777",
      "color-basic-700": "#555",
      "color-basic-800": "#333",
      "color-basic-900": "#111",
      "color-danger-500": "#FF3D71",
    }),
  };
});

jest.mock("@/components/AppHeader", () => {
  const { View, TouchableOpacity } = require("react-native");
  return {
    AppHeader: ({ onBack, rightActions }: { onBack: () => void; rightActions?: React.ReactNode }) => (
      <View>
        <TouchableOpacity testID="back-button" onPress={onBack} />
        {rightActions}
      </View>
    ),
    AppHeaderIconButton: ({ onPress, testID }: { onPress: () => void; testID?: string }) => (
      <TouchableOpacity testID={testID ?? "header-icon-btn"} onPress={onPress} />
    ),
  };
});

jest.mock("react-native-markdown-display", () => {
  const { Text } = require("react-native");
  return ({ children }: { children: string }) => <Text testID="markdown-display">{children}</Text>;
});

jest.mock("@expo/vector-icons", () => ({
  Ionicons: "Ionicons",
}));

// ─── Imports under test ───────────────────────────────────────────────────────

import { DetailsContainer } from "../../Views/Details/DetailsContainer";
import * as recordingService from "@/services/recordingService";
import * as database from "@/utils/database";
import {
  useRouter,
  useNavigation,
  useLocalSearchParams,
} from "expo-router";

// ─── Test helpers ─────────────────────────────────────────────────────────────

const MOCK_RECORDING_RECORD = {
  id: "rec-001",
  title: "Standup 2026-04-14",
  summary: "Discussed sprint goals.",
  timestamp: "09:30",
  duration: "5:12",
  badge: "Work",
  isProcessing: 0,
  audioFilePath: "/data/recordings/rec-001.m4a",
  createdAt: 1713091800000,
  workspaceId: "",
  notes: "These are the saved notes.",
};

interface NavigationEvent {
  preventDefault: jest.Mock;
  data: { action: { type: string } };
}

interface NavigationListener {
  (event: NavigationEvent): void;
}

function setupNavigation() {
  let beforeRemoveListener: NavigationListener | null = null;
  const mockDispatch = jest.fn();
  const mockNavigation = {
    addListener: jest.fn(
      (event: string, callback: NavigationListener) => {
        if (event === "beforeRemove") {
          beforeRemoveListener = callback;
        }
        return jest.fn();
      },
    ),
    dispatch: mockDispatch,
  };

  return {
    mockNavigation,
    mockDispatch,
    fireBeforeRemove: () => {
      const mockEvent: NavigationEvent = {
        preventDefault: jest.fn(),
        data: { action: { type: "GO_BACK" } },
      };
      if (beforeRemoveListener) {
        beforeRemoveListener(mockEvent);
      }
      return mockEvent;
    },
  };
}

function setupMocks(recordOverride?: Partial<typeof MOCK_RECORDING_RECORD>) {
  const record = { ...MOCK_RECORDING_RECORD, ...recordOverride };
  (useLocalSearchParams as jest.Mock).mockReturnValue({ id: record.id });
  (recordingService.getRecordingById as jest.Mock).mockResolvedValue(record);
  (recordingService.updateRecording as jest.Mock).mockResolvedValue(undefined);
  (database.initDatabase as jest.Mock).mockResolvedValue(undefined);

  const routerMock = { back: jest.fn() };
  (useRouter as jest.Mock).mockReturnValue(routerMock);

  return { record, routerMock };
}

async function waitForRecordingLoaded() {
  await waitFor(() => expect(recordingService.getRecordingById).toHaveBeenCalled());
  await waitFor(() => {
    expect(
      screen.queryByText("details.edit") ??
        screen.queryByPlaceholderText("details.notesPlaceholder"),
    ).toBeTruthy();
  });
}

// ─── beforeRemove guard ───────────────────────────────────────────────────────

describe("DetailsContainer — beforeRemove navigation guard", () => {
  let alertSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    alertSpy = jest.spyOn(Alert, "alert").mockImplementation(() => {});
  });

  afterEach(() => {
    alertSpy.mockRestore();
  });

  it("should NOT show alert when navigating away with no unsaved changes", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks();

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    nav.fireBeforeRemove();

    expect(alertSpy).not.toHaveBeenCalled();
  });

  it("should show alert and prevent default when navigating away with unsaved edits", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Original notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    const textInput = screen.getByPlaceholderText("details.notesPlaceholder");
    fireEvent.changeText(textInput, "Original notes — edited by user");

    const event = nav.fireBeforeRemove();

    await waitFor(() => {
      expect(event.preventDefault).toHaveBeenCalledTimes(1);
      expect(alertSpy).toHaveBeenCalledTimes(1);
      expect(alertSpy).toHaveBeenCalledWith(
        "Unsaved changes",
        expect.any(String),
        expect.arrayContaining([
          expect.objectContaining({ style: "cancel" }),
          expect.objectContaining({ style: "destructive" }),
        ]),
      );
    });
  });

  /**
   * W-01 REGRESSION TEST
   *
   * With the BUGGY code (!isDirty || !isEditing guard), this test FAILS —
   * demonstrating the bug. After the W-01 fix (remove !isEditing), it passes.
   *
   * Scenario: user edits → switches to Preview → navigates back.
   * The guard must still fire even though isEditing is false.
   */
  it("W-01: should show alert when user edits then switches to Preview before navigating", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Saved notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    const textInput = screen.getByPlaceholderText("details.notesPlaceholder");
    fireEvent.changeText(textInput, "Saved notes — with unsaved edits");

    // Switch back to Preview (this is what exposes the W-01 bug)
    fireEvent.press(screen.getByText("details.preview"));

    const event = nav.fireBeforeRemove();

    await waitFor(() => {
      expect(event.preventDefault).toHaveBeenCalledTimes(1);
      expect(alertSpy).toHaveBeenCalledTimes(1);
    });
  });

  it("should dispatch navigation action when user presses Discard", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Original" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    fireEvent.changeText(
      screen.getByPlaceholderText("details.notesPlaceholder"),
      "Original — edited",
    );

    nav.fireBeforeRemove();
    await waitFor(() => expect(alertSpy).toHaveBeenCalled());

    const buttons = alertSpy.mock.calls[0][2] as Array<{ style?: string; onPress?: () => void }>;
    const discardButton = buttons.find((b) => b.style === "destructive");
    act(() => { discardButton?.onPress?.(); });

    expect(nav.mockDispatch).toHaveBeenCalledWith({ type: "GO_BACK" });
  });

  it("should NOT dispatch navigation when user presses Keep editing", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Original" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    fireEvent.changeText(
      screen.getByPlaceholderText("details.notesPlaceholder"),
      "Original — edited",
    );

    nav.fireBeforeRemove();
    await waitFor(() => expect(alertSpy).toHaveBeenCalled());

    const buttons = alertSpy.mock.calls[0][2] as Array<{ style?: string; onPress?: () => void }>;
    const cancelButton = buttons.find((b) => b.style === "cancel");
    act(() => { cancelButton?.onPress?.(); });

    expect(nav.mockDispatch).not.toHaveBeenCalled();
  });

  it("should NOT show alert after a successful save clears the dirty flag", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Original" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    fireEvent.changeText(
      screen.getByPlaceholderText("details.notesPlaceholder"),
      "Original — edited",
    );

    await act(async () => {
      fireEvent.press(screen.getByTestId("fab-save"));
    });

    await waitFor(() =>
      expect(recordingService.updateRecording).toHaveBeenCalledWith(
        "rec-001",
        { notes: "Original — edited" },
      ),
    );

    const event = nav.fireBeforeRemove();
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(alertSpy).not.toHaveBeenCalled();
  });
});

// ─── Dirty dot on FAB ─────────────────────────────────────────────────────────

describe("DetailsContainer — isDirty dirty dot on FAB", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should not render the dirty dot when content matches saved state", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Clean notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    expect(screen.queryByTestId("fab-dirty-dot")).toBeNull();
  });

  it("should render the dirty dot after the user makes an edit", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Original" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    fireEvent.changeText(
      screen.getByPlaceholderText("details.notesPlaceholder"),
      "Original — user typed something",
    );

    expect(screen.getByTestId("fab-dirty-dot")).toBeTruthy();
  });

  it("should remove the dirty dot after a successful save", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Original" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    fireEvent.changeText(
      screen.getByPlaceholderText("details.notesPlaceholder"),
      "Original — edited",
    );

    await act(async () => {
      fireEvent.press(screen.getByTestId("fab-save"));
    });

    await waitFor(() => expect(screen.queryByTestId("fab-dirty-dot")).toBeNull());
  });
});

// ─── Edit / Preview toggle ────────────────────────────────────────────────────

describe("DetailsContainer — Edit/Preview toggle", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should start in Preview mode when recording has existing notes", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Existing notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    expect(screen.getByTestId("markdown-display")).toBeTruthy();
    expect(screen.queryByPlaceholderText("details.notesPlaceholder")).toBeNull();
    expect(screen.getByText("details.edit")).toBeTruthy();
  });

  it("should start in Edit mode when recording has no notes", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: undefined, summary: undefined });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    expect(screen.getByPlaceholderText("details.notesPlaceholder")).toBeTruthy();
    expect(screen.queryByTestId("markdown-display")).toBeNull();
    expect(screen.getByText("details.preview")).toBeTruthy();
  });

  it("should switch to edit mode when the Edit button is pressed", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Some notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));

    expect(screen.getByPlaceholderText("details.notesPlaceholder")).toBeTruthy();
    expect(screen.queryByTestId("markdown-display")).toBeNull();
  });

  it("should switch to preview mode when the Preview button is pressed", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: undefined, summary: undefined });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.preview"));

    expect(screen.getByTestId("markdown-display")).toBeTruthy();
    expect(screen.queryByPlaceholderText("details.notesPlaceholder")).toBeNull();
  });

  it("should preserve transcript content when toggling between Edit and Preview", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Initial notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    fireEvent.changeText(
      screen.getByPlaceholderText("details.notesPlaceholder"),
      "Initial notes — modified",
    );

    fireEvent.press(screen.getByText("details.preview"));
    expect(screen.getByTestId("markdown-display").props.children).toBe("Initial notes — modified");

    fireEvent.press(screen.getByText("details.edit"));
    expect(screen.getByPlaceholderText("details.notesPlaceholder").props.value).toBe(
      "Initial notes — modified",
    );
  });

  it("should show markdown toolbar only in edit mode", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Some notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    // Preview mode — toolbar not visible
    expect(screen.queryByText("B")).toBeNull();

    fireEvent.press(screen.getByText("details.edit"));

    expect(screen.getByText("B")).toBeTruthy();
    expect(screen.getByText("I")).toBeTruthy();
    expect(screen.getByText("H")).toBeTruthy();
    expect(screen.getByText("•")).toBeTruthy();
    expect(screen.getByText("[ ]")).toBeTruthy();
  });
});

// ─── Initial load ─────────────────────────────────────────────────────────────

describe("DetailsContainer — initial load", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should prefer notes over summary as the initial transcript", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Explicit user notes", summary: "AI-generated summary" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    fireEvent.press(screen.getByText("details.edit"));
    expect(screen.getByPlaceholderText("details.notesPlaceholder").props.value).toBe(
      "Explicit user notes",
    );
  });

  it("should fall back to summary when notes are absent", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: undefined, summary: "AI summary only" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    expect(screen.getByTestId("markdown-display").props.children).toBe("AI summary only");
  });

  it("should navigate back when recording is not found", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    const routerMock = { back: jest.fn() };
    (useRouter as jest.Mock).mockReturnValue(routerMock);
    (useLocalSearchParams as jest.Mock).mockReturnValue({ id: "nonexistent" });
    (recordingService.getRecordingById as jest.Mock).mockResolvedValue(null);

    render(<DetailsContainer />);
    await waitFor(() => expect(routerMock.back).toHaveBeenCalled());
  });

  it("should not be dirty on initial load", async () => {
    const nav = setupNavigation();
    (useNavigation as jest.Mock).mockReturnValue(nav.mockNavigation);
    setupMocks({ notes: "Pre-existing notes" });

    render(<DetailsContainer />);
    await waitForRecordingLoaded();

    expect(screen.queryByTestId("fab-dirty-dot")).toBeNull();
  });
});

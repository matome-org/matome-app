import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import { Text, useTheme } from '@ui-kitten/components';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import {
  cancelRecording,
  discardSegments,
  formatDuration,
  getRecordingDuration,
  getRecordingMetering,
  isRecorderActive,
  pauseRecording,
  releaseRecorder,
  restoreSegments,
  resumeRecording,
  saveRecordingFromSegments,
  startRecording,
  stopRecording,
} from '@/services/audioRecordingService';
import {
  deleteDraft,
  loadDraft,
  saveDraft,
} from '@/services/draftRecordingService';
import { useRecordingsStore } from '@/stores/recordingsStore';

// ---------------------------------------------------------------------------
// Recording lifecycle:
//   draft_check  — loading draft from DB on mount (brief)
//   draft_prompt — draft found, showing Resume / Discard prompt
//   idle         — screen opened fresh, not yet recording
//   recording    — mic active, segment in progress
//   paused       — segment stopped, audio preserved, can resume or finish
//   processing   — merging + saving in progress
// ---------------------------------------------------------------------------
type RecordingPhase =
  | 'draft_check'
  | 'draft_prompt'
  | 'idle'
  | 'recording'
  | 'paused'
  | 'processing';

const WAVEFORM_BARS = 20;

export default function RecordingScreen() {
  const theme = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { t } = useTranslation();
  const triggerRefresh = useRecordingsStore((s) => s.triggerRefresh);

  // hasDraft=1 is set by NavigationGuard when a draft is detected at startup
  const { hasDraft } = useLocalSearchParams<{ hasDraft?: string }>();

  const [phase, setPhase] = useState<RecordingPhase>(
    hasDraft === '1' ? 'draft_check' : 'idle',
  );
  const [totalDuration, setTotalDuration] = useState(0);
  const [meteringBars, setMeteringBars] = useState<number[]>(() =>
    Array(WAVEFORM_BARS).fill(0),
  );

  // Segments accumulated across pause/resume cycles
  const segmentsRef = useRef<string[]>([]);
  // Duration accumulated in already-completed segments (seconds)
  const completedDurationRef = useRef<number>(0);

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const meteringBufferRef = useRef<number[]>(Array(WAVEFORM_BARS).fill(0));
  const lastHeightRef = useRef<number>(5);

  // Mirror of `phase` so the unmount cleanup effect (empty-dep, fixed at mount)
  // can read the LATEST phase instead of a stale closure value.
  const phaseRef = useRef<RecordingPhase>(phase);
  phaseRef.current = phase;

  // ---------------------------------------------------------------------------
  // Draft check on mount — only runs when hasDraft=1 param is present
  // ---------------------------------------------------------------------------
  useEffect(() => {
    if (hasDraft !== '1') return;

    const checkDraft = async () => {
      try {
        const draft = await loadDraft();
        if (draft && draft.segments.length > 0) {
          // Load draft segments into ref and show the resume prompt
          segmentsRef.current = draft.segments;
          completedDurationRef.current = draft.durationMs / 1000;
          setTotalDuration(draft.durationMs / 1000);
          setPhase('draft_prompt');
        } else {
          // Draft was empty or deleted since the guard fired — proceed fresh
          setPhase('idle');
        }
      } catch (error) {
        console.error('RecordingScreen: Failed to load draft', error);
        setPhase('idle');
      }
    };

    checkDraft();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // ---------------------------------------------------------------------------
  // Metering interval — runs while phase === 'recording'
  // ---------------------------------------------------------------------------
  useEffect(() => {
    if (phase === 'recording') {
      intervalRef.current = setInterval(() => {
        const currentSegmentDuration = getRecordingDuration();
        setTotalDuration(completedDurationRef.current + currentSegmentDuration);

        const metering = getRecordingMetering();
        if (metering !== undefined) {
          const minDb = -60;
          const maxDb = 0;
          let normalized = (metering - minDb) / (maxDb - minDb);
          normalized = Math.max(0, Math.min(1, normalized));

          const targetHeight = normalized * 40 + 5;
          let finalHeight: number;

          if (targetHeight > lastHeightRef.current) {
            finalHeight = targetHeight;
          } else {
            finalHeight = lastHeightRef.current * 0.7 + targetHeight * 0.3;
          }

          finalHeight = Math.max(5, finalHeight);
          lastHeightRef.current = finalHeight;

          const buffer = [...meteringBufferRef.current.slice(1), finalHeight];
          meteringBufferRef.current = buffer;
          setMeteringBars(buffer);
        }
      }, 80);
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }

      if (phase === 'idle' || phase === 'processing' || phase === 'draft_check') {
        const empty = Array(WAVEFORM_BARS).fill(0);
        meteringBufferRef.current = empty;
        setMeteringBars(empty);
        lastHeightRef.current = 5;
      }
    }

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [phase]);

  // ---------------------------------------------------------------------------
  // Unmount cleanup — release leaked native resources if the screen is torn
  // down mid-session (app backgrounded/killed, gesture dismiss, navigation away).
  //
  // Reads phaseRef (not `phase`) so the empty-dep closure sees the LATEST phase.
  //
  //   • recording: the mic is live → stop the recorder + clear the service's
  //     80ms metering interval to release the native mic session. Segment files
  //     accumulated so far are left on disk (recoverable; not discarded here).
  //   • paused: a draft was intentionally auto-saved on pause. The live recorder
  //     is already stopped, but call releaseRecorder() defensively to clear any
  //     dangling interval — it does NOT discard segments, so the draft + its
  //     segment files survive for recovery.
  //   • idle / other: no live recorder; releaseRecorder() is a safe no-op that
  //     still guarantees no metering interval is left running.
  //
  // releaseRecorder() never deletes segment files or the draft (unlike
  // cancelRecording), so draft-on-pause recovery is preserved.
  // ---------------------------------------------------------------------------
  useEffect(() => {
    return () => {
      // Always clear the local UI metering interval.
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }

      // Read the LATEST phase via the ref (the empty-dep closure would otherwise
      // capture a stale 'idle'/'draft_check' value from mount time).
      const livePhase = phaseRef.current;

      // releaseRecorder() stops the native recorder + service metering interval
      // WITHOUT discarding segments or the draft. For 'recording' this frees the
      // live mic; for 'paused' it just clears any dangling interval while the
      // saved draft + segment files are preserved for recovery; for any other
      // phase it is a safe no-op. We call it whenever a session may be live or
      // a timer may be dangling.
      if (livePhase !== 'processing') {
        void releaseRecorder().catch((e) =>
          console.error(
            'RecordingScreen: Failed to release recorder on unmount',
            e,
          ),
        );
      }
    };
  }, []);

  // ---------------------------------------------------------------------------
  // Action handlers
  // ---------------------------------------------------------------------------

  const handleStart = useCallback(async () => {
    try {
      await startRecording();

      // Draft-recovery seed — THE real recovery path. After an app restart the
      // recovered draft's prior spans live in segmentsRef.current (loaded by the
      // mount draft-check), but the module-level sessionSegments is empty (fresh
      // JS process) and startRecording() above just RESET it to []. Re-seed the
      // recovered spans NOW, AFTER startRecording's reset, so the subsequent
      // stopRecording() APPENDS the new span → sessionSegments = [...priorSpans,
      // newSpan], yielding a complete multi-span transcript and a discardSegments
      // that cleans EVERY file (no leak).
      //
      // ORDERING (critical): startRecording() → restoreSegments([prior]) →
      // (later) stopRecording() appends. Skip entirely when segmentsRef is empty
      // (normal live record) so that path stays a single continuous file.
      const priorSpans = [...segmentsRef.current];
      if (priorSpans.length > 0) {
        restoreSegments(priorSpans);
        // Carry the recovered elapsed time so the on-screen timer continues from
        // the pre-restart duration instead of resetting to 0.
        completedDurationRef.current = totalDuration;
      }

      setPhase('recording');
    } catch (error) {
      console.error('RecordingScreen: Failed to start recording', error);
      alert(t('recording.startFailed'));
    }
  }, [totalDuration, t]);

  /**
   * Pause — natively suspend the SINGLE live recorder (no segment split, so no
   * audio is lost), snapshot it for crash-recovery, and auto-save draft state so
   * the session can be recovered after an app restart.
   *
   * pauseRecording() keeps one underlying file open; handleResume continues
   * appending to it. The full session therefore lands in one file at Finish.
   */
  const handlePause = useCallback(async () => {
    try {
      const snapshotUri = await pauseRecording();
      // Single-file model: the live recorder owns the full audio. The snapshot
      // is the lone recoverable segment, so the draft tracks just it.
      segmentsRef.current = [snapshotUri];
      completedDurationRef.current = totalDuration;
      setPhase('paused');

      // Auto-save draft so the session survives an app restart
      await saveDraft(segmentsRef.current, Math.round(totalDuration * 1000));
    } catch (error) {
      console.error('RecordingScreen: Failed to pause recording', error);
      // Surface the failure: pause didn't succeed, so keep the user in the live
      // 'recording' phase rather than silently showing 'paused'.
      setPhase('recording');
      alert(t('recording.pauseFailed'));
    }
  }, [totalDuration, t]);

  /**
   * Resume — continue the SAME native recorder (appends to the single file).
   *
   * If there is no live recorder (e.g. the session was recovered from a draft
   * after an app restart, where the recorder no longer exists), fall back to
   * starting a fresh recorder — that recovered case is the only path that can
   * produce a second segment, handled defensively by the merge/transcription
   * pipeline.
   */
  const handleResume = useCallback(async () => {
    try {
      await resumeRecording();
      // resumeRecording continues the existing recorder; completed duration is
      // already reflected by the recorder's cumulative native duration.
      completedDurationRef.current = 0;
      setPhase('recording');
    } catch {
      // No live recorder to resume (recovered draft, post-restart) — start a new
      // segment. ORDERING HAZARD: startRecording() resets the module's
      // sessionSegments to []. So we must snapshot the recovered prior spans
      // FIRST, then call startRecording(), then re-seed via restoreSegments() so
      // the restored spans survive the reset. On the subsequent Finish,
      // stopRecording() APPENDS the new span → sessionSegments = [...priorSpans,
      // newSpan], yielding a transcript that covers EVERY span (pre- and
      // post-restart) and discardSegments() that cleans ALL files (no leak).
      const priorSpans = [...segmentsRef.current];
      try {
        await startRecording();
        // Re-seed AFTER startRecording's reset (the crux). Skip when there were
        // no recovered spans (fresh start) — restoreSegments([]) would be a
        // harmless no-op but we keep the seeded module state explicit only when
        // there is something to restore.
        if (priorSpans.length > 0) {
          restoreSegments(priorSpans);
        }
        // Carry the recovered elapsed duration so the on-screen timer continues
        // from the pre-restart time instead of dropping to 0.
        completedDurationRef.current = totalDuration;
        setPhase('recording');
      } catch (startError) {
        console.error('RecordingScreen: Failed to resume recording', startError);
        alert(t('recording.resumeFailed'));
      }
    }
  }, [totalDuration, t]);

  /**
   * Cancel — discard all segments, delete the draft record, and navigate back.
   */
  const handleCancel = useCallback(async () => {
    if (phase === 'recording') {
      try {
        // cancelRecording also calls discardSegments internally
        await cancelRecording();
      } catch (error) {
        console.error('RecordingScreen: Error canceling active recording', error);
      }
    } else {
      // Not actively recording — still need to discard any paused segments
      await discardSegments().catch((e) =>
        console.error('RecordingScreen: Failed to discard segments on cancel', e),
      );
    }
    segmentsRef.current = [];
    completedDurationRef.current = 0;
    await deleteDraft().catch((e) =>
      console.error('RecordingScreen: Failed to delete draft on cancel', e),
    );
    router.back();
  }, [phase, router]);

  /**
   * Draft — Resume: load prior segments and continue recording.
   */
  const handleDraftResume = useCallback(async () => {
    // segmentsRef and completedDurationRef are already populated from the
    // draft check. Simply transition to idle so the user can tap Start.
    setPhase('idle');
  }, []);

  /**
   * Draft — Discard: delete all segment files and the draft record, then
   * transition to a fresh idle state.
   */
  const handleDraftDiscard = useCallback(async () => {
    await discardSegments().catch((e) =>
      console.error('RecordingScreen: Failed to discard draft segments', e),
    );
    await deleteDraft().catch((e) =>
      console.error('RecordingScreen: Failed to delete draft record', e),
    );
    segmentsRef.current = [];
    completedDurationRef.current = 0;
    setTotalDuration(0);
    setPhase('idle');
  }, []);

  /**
   * Finish — finalize the live recorder (if any), then save/upload.
   *
   * Single-file model: an in-app session is one native recorder (recording or
   * paused). stopRecording() finalizes it into ONE file holding the complete
   * audio across every pause/resume span — the multi-segment audio-loss defect
   * is gone. We finalize from BOTH 'recording' and 'paused' so a Finish tapped
   * while paused still flushes (and releases) the live recorder.
   *
   * Recovered-draft fallback: if the draft was restored after an app restart
   * there is no live recorder; the persisted segment file(s) already hold the
   * audio, so we skip stopRecording() and let saveRecordingFromSegments use the
   * module's sessionSegments (transcribing every segment defensively).
   */
  const handleFinish = useCallback(async () => {
    setPhase('processing');

    try {
      if ((phase === 'recording' || phase === 'paused') && isRecorderActive()) {
        // Finalize the live recorder into the single complete-session file.
        // stopRecording() supersedes any pause-snapshot in module state.
        const segmentUri = await stopRecording();
        segmentsRef.current = [segmentUri];
      }

      // saveRecordingFromSegments reads sessionSegments from module state,
      // merges them (or selects the last), transcribes all, and saves to DB.
      const recordingId = await saveRecordingFromSegments('Inbox');

      // Clean up segment files and draft record
      await discardSegments().catch((e) =>
        console.error('RecordingScreen: Failed to discard segments after finish', e),
      );
      await deleteDraft().catch((e) =>
        console.error('RecordingScreen: Failed to delete draft after finish', e),
      );

      triggerRefresh();

      // Replace this full-screen modal route with the recording-detail screen in
      // a single navigation. The previous back()+push() sequence raced the
      // modal-dismiss animation against the push and could land on the wrong
      // screen; replace() dismisses and navigates atomically.
      //
      // Route target: the detail screen lives at app/(tabs)/inbox/[id].tsx
      // (DetailsContainer). We use the FULLY-QUALIFIED `/(tabs)/inbox/${id}` form
      // so the destination unambiguously sits inside the (tabs) group — this
      // matches the convention used by _layout.tsx ('/(tabs)/explore/explore')
      // and CalendarContainer ('/(tabs)/calendar/${id}'). Landing inside (tabs)
      // means NavigationGuard's `isAuthenticated && !inTabsGroup` branch
      // (segments[0] === '(tabs)') will NOT bounce the navigation to explore.
      router.replace(`/(tabs)/inbox/${recordingId}`);
    } catch (error) {
      console.error('RecordingScreen: Failed to finish recording', error);
      setPhase('paused');
      alert(t('recording.saveFailed'));
    }
  }, [phase, router, triggerRefresh, t]);

  // ---------------------------------------------------------------------------
  // Waveform renderer
  // ---------------------------------------------------------------------------
  const renderWaveform = useCallback(
    () =>
      meteringBars.map((height, i) => (
        <View
          key={i}
          style={[
            styles.waveBar,
            {
              height: height > 0 ? height : 5,
              backgroundColor:
                phase === 'recording'
                  ? theme['color-primary-500']
                  : theme['color-basic-400'],
            },
          ]}
        />
      )),
    [phase, theme, meteringBars],
  );

  // ---------------------------------------------------------------------------
  // Derived display values
  // ---------------------------------------------------------------------------
  const statusLabel = (() => {
    switch (phase) {
      case 'draft_check':
      case 'draft_prompt':
        return t('recording.draftFound');
      case 'idle':
        return t('recording.ready');
      case 'recording':
        return t('recording.title');
      case 'paused':
        return t('recording.paused');
      case 'processing':
        return t('recording.processing');
    }
  })();

  const hintLabel = (() => {
    switch (phase) {
      case 'draft_check':
        return '';
      case 'draft_prompt':
        return t('recording.draftHint');
      case 'idle':
        return t('recording.startHint');
      case 'recording':
        return t('recording.stopHint');
      case 'paused':
        return t('recording.resumeHint');
      case 'processing':
        return '';
    }
  })();

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------
  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: theme['color-basic-100'],
          paddingTop: insets.top + 16,
          paddingBottom: insets.bottom + 16,
        },
      ]}
    >
      {/* Close / Cancel button — hidden during processing and draft_check */}
      {phase !== 'processing' && phase !== 'draft_check' && (
        <Pressable
          style={styles.closeButton}
          onPress={handleCancel}
          accessibilityLabel={t('common.cancel')}
        >
          <Ionicons name="close" size={28} color={theme['color-basic-700']} />
        </Pressable>
      )}

      {/* ------------------------------------------------------------------ */}
      {/* Processing state                                                    */}
      {/* ------------------------------------------------------------------ */}
      {(phase === 'processing' || phase === 'draft_check') && (
        <View style={styles.processingContainer}>
          <ActivityIndicator size="large" color={theme['color-primary-500']} />
          <Text
            category="s1"
            style={[styles.processingText, { color: theme['color-basic-600'] }]}
          >
            {phase === 'draft_check'
              ? t('recording.loading')
              : t('recording.processing')}
          </Text>
        </View>
      )}

      {/* ------------------------------------------------------------------ */}
      {/* Draft recovery prompt                                               */}
      {/* ------------------------------------------------------------------ */}
      {phase === 'draft_prompt' && (
        <View style={styles.content}>
          <View
            style={[
              styles.draftIcon,
              { backgroundColor: theme['color-warning-500'] + '20' },
            ]}
          >
            <Ionicons
              name="mic-circle-outline"
              size={48}
              color={theme['color-warning-500']}
            />
          </View>

          <Text
            category="h5"
            style={[styles.title, { color: theme['color-basic-800'] }]}
          >
            {statusLabel}
          </Text>

          <Text
            category="p1"
            style={[styles.hint, { color: theme['color-basic-600'] }]}
          >
            {hintLabel}
          </Text>

          {totalDuration > 0 && (
            <Text style={[styles.timer, { color: theme['color-basic-800'] }]}>
              {formatDuration(totalDuration)}
            </Text>
          )}

          <View style={styles.buttonRow}>
            <Pressable
              style={[styles.actionButton, styles.cancelButton]}
              onPress={handleDraftDiscard}
            >
              <Text style={styles.cancelButtonText}>
                {t('recording.draftDiscard')}
              </Text>
            </Pressable>
            <Pressable
              style={[
                styles.actionButton,
                styles.finishButton,
                { backgroundColor: theme['color-primary-500'] },
              ]}
              onPress={handleDraftResume}
            >
              <Text style={styles.finishButtonText}>
                {t('recording.draftResume')}
              </Text>
            </Pressable>
          </View>
        </View>
      )}

      {/* ------------------------------------------------------------------ */}
      {/* Active recording / paused / idle UI                                */}
      {/* ------------------------------------------------------------------ */}
      {(phase === 'idle' || phase === 'recording' || phase === 'paused') && (
        <View style={styles.content}>
          <Text
            category="h4"
            style={[styles.title, { color: theme['color-basic-800'] }]}
          >
            {statusLabel}
          </Text>

          <Text
            category="c1"
            style={[styles.hint, { color: theme['color-basic-600'] }]}
          >
            {hintLabel}
          </Text>

          {/* Timer — shown whenever there is accumulated duration */}
          {totalDuration > 0 && (
            <Text style={[styles.timer, { color: theme['color-basic-800'] }]}>
              {formatDuration(totalDuration)}
            </Text>
          )}

          {/* Waveform */}
          <View style={styles.waveform}>{renderWaveform()}</View>

          {/* Primary action button */}
          <Pressable
            style={[
              styles.recordingIndicator,
              {
                backgroundColor:
                  phase === 'recording'
                    ? theme['color-danger-500'] + '20'
                    : theme['color-primary-500'] + '20',
              },
            ]}
            onPress={
              phase === 'idle'
                ? handleStart
                : phase === 'recording'
                ? handlePause
                : handleResume
            }
          >
            <View
              style={[
                styles.recordingButton,
                {
                  backgroundColor:
                    phase === 'recording'
                      ? theme['color-danger-500']
                      : theme['color-primary-500'],
                },
              ]}
            >
              <View
                style={[
                  styles.recordingButtonInner,
                  {
                    backgroundColor:
                      phase === 'recording'
                        ? theme['color-danger-100']
                        : theme['color-primary-100'],
                  },
                ]}
              />
            </View>
          </Pressable>

          {/* Secondary actions */}
          <View style={styles.buttonRow}>
            <Pressable
              style={[styles.actionButton, styles.cancelButton]}
              onPress={handleCancel}
            >
              <Text style={styles.cancelButtonText}>{t('common.cancel')}</Text>
            </Pressable>

            {phase === 'recording' && (
              <Pressable
                style={[
                  styles.actionButton,
                  styles.pauseButton,
                  { borderColor: theme['color-primary-500'] },
                ]}
                onPress={handlePause}
              >
                <Text style={[styles.pauseButtonText, { color: theme['color-primary-500'] }]}>
                  {t('recording.pause')}
                </Text>
              </Pressable>
            )}

            {(phase === 'recording' || phase === 'paused') && (
              <Pressable
                style={[
                  styles.actionButton,
                  styles.finishButton,
                  { backgroundColor: theme['color-primary-500'] },
                ]}
                onPress={handleFinish}
              >
                <Text style={styles.finishButtonText}>
                  {t('recording.finish')}
                </Text>
              </Pressable>
            )}
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  closeButton: {
    position: 'absolute',
    top: 56,
    right: 20,
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
  },
  processingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 20,
  },
  processingText: {
    fontSize: 16,
    marginTop: 8,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    gap: 8,
  },
  draftIcon: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  title: {
    fontWeight: '700',
    textAlign: 'center',
    marginBottom: 4,
  },
  hint: {
    textAlign: 'center',
    marginBottom: 24,
  },
  timer: {
    fontSize: 40,
    fontWeight: '600',
    fontVariant: ['tabular-nums'],
    marginBottom: 16,
  },
  waveform: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 40,
    marginBottom: 32,
    gap: 4,
  },
  waveBar: {
    width: 4,
    borderRadius: 2,
  },
  recordingIndicator: {
    width: 200,
    height: 200,
    borderRadius: 100,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 40,
  },
  recordingButton: {
    width: 80,
    height: 80,
    borderRadius: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  recordingButtonInner: {
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
    width: '100%',
  },
  actionButton: {
    flex: 1,
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cancelButton: {
    backgroundColor: '#f0f0f0',
  },
  cancelButtonText: {
    color: '#333',
    fontWeight: '600',
    fontSize: 16,
  },
  pauseButton: {
    borderWidth: 2,
    backgroundColor: 'transparent',
  },
  pauseButtonText: {
    fontWeight: '600',
    fontSize: 16,
  },
  finishButton: {},
  finishButtonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
});

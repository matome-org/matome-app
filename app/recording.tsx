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
  mergeSegments,
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
  // Action handlers
  // ---------------------------------------------------------------------------

  const handleStart = useCallback(async () => {
    try {
      await startRecording();
      setPhase('recording');
    } catch (error) {
      console.error('RecordingScreen: Failed to start recording', error);
      alert('Failed to start recording. Please check microphone permissions.');
    }
  }, []);

  /**
   * Pause — stop the current segment, preserve it, and auto-save draft state
   * so the session can be recovered after an app restart.
   */
  const handlePause = useCallback(async () => {
    try {
      const segmentUri = await stopRecording();
      const updatedSegments = [...segmentsRef.current, segmentUri];
      segmentsRef.current = updatedSegments;
      completedDurationRef.current = totalDuration;
      setPhase('paused');

      // Auto-save draft so the session survives an app restart
      await saveDraft(updatedSegments, Math.round(totalDuration * 1000));
    } catch (error) {
      console.error('RecordingScreen: Failed to pause recording', error);
    }
  }, [totalDuration]);

  /**
   * Resume — start a new segment. Duration accumulates from prior segments.
   */
  const handleResume = useCallback(async () => {
    try {
      await startRecording();
      setPhase('recording');
    } catch (error) {
      console.error('RecordingScreen: Failed to resume recording', error);
      alert('Failed to resume recording. Please try again.');
    }
  }, []);

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
   * Finish — stop the active segment if needed, merge all segments into one
   * file, trigger the save/upload pipeline, then clean up.
   *
   * Merge strategy: see mergeSegments() in audioRecordingService for details.
   * For multi-segment M4A sessions the last segment is used as the audio file
   * while all segments are transcribed individually and their transcripts
   * are joined. Full binary merge requires a native audio module (future work).
   */
  const handleFinish = useCallback(async () => {
    setPhase('processing');

    try {
      if (phase === 'recording') {
        // Stop the current active segment — it will be added to sessionSegments
        // inside stopRecording (which also appends to segmentsRef via side effect)
        const segmentUri = await stopRecording();
        segmentsRef.current = [...segmentsRef.current, segmentUri];
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

      router.back();
      router.push(`/inbox/${recordingId}`);
    } catch (error) {
      console.error('RecordingScreen: Failed to finish recording', error);
      setPhase('paused');
      alert('Failed to save recording. Please try again.');
    }
  }, [phase, router, triggerRefresh]);

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

            {phase === 'paused' && (
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

            {phase === 'recording' && (
              <Pressable
                style={[
                  styles.actionButton,
                  styles.finishButton,
                  { backgroundColor: theme['color-danger-500'] },
                ]}
                onPress={handleFinish}
              >
                <Text style={styles.finishButtonText}>
                  {t('recording.stop')}
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
  finishButton: {},
  finishButtonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
});

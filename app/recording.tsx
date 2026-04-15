import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  View,
} from 'react-native';
import { Text, useTheme } from '@ui-kitten/components';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import {
  cancelRecording,
  formatDuration,
  getRecordingDuration,
  getRecordingMetering,
  saveRecording,
  startRecording,
  stopRecording,
} from '@/services/audioRecordingService';
import { saveDraft, deleteDraft } from '@/services/draftRecordingService';
import { useRecordingsStore } from '@/stores/recordingsStore';

// ---------------------------------------------------------------------------
// Recording lifecycle:
//   idle      — screen just opened, not yet recording
//   recording — mic active, segment in progress
//   paused    — segment stopped, audio preserved, can resume or finish
//   processing — merging + saving in progress
// ---------------------------------------------------------------------------
type RecordingPhase = 'idle' | 'recording' | 'paused' | 'processing';

const WAVEFORM_BARS = 20;

export default function RecordingScreen() {
  const theme = useTheme();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { t } = useTranslation();
  const triggerRefresh = useRecordingsStore((s) => s.triggerRefresh);

  const [phase, setPhase] = useState<RecordingPhase>('idle');
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
            finalHeight =
              lastHeightRef.current * 0.7 + targetHeight * 0.3;
          }

          finalHeight = Math.max(5, finalHeight);
          lastHeightRef.current = finalHeight;

          const buffer = [
            ...meteringBufferRef.current.slice(1),
            finalHeight,
          ];
          meteringBufferRef.current = buffer;
          setMeteringBars(buffer);
        }
      }, 80);
    } else {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }

      if (phase === 'idle' || phase === 'processing') {
        // Reset waveform when idle or processing
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
   * Resume — start a new segment. Duration accumulates.
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
    }
    segmentsRef.current = [];
    completedDurationRef.current = 0;
    await deleteDraft().catch((e) =>
      console.error('RecordingScreen: Failed to delete draft on cancel', e),
    );
    router.back();
  }, [phase, router]);

  /**
   * Finish — if currently recording, stop the active segment first, then
   * trigger the save/upload pipeline with the last segment.
   * For single-segment sessions this is equivalent to the original flow.
   * Multi-segment merging (Task 2C) will extend this function.
   */
  const handleFinish = useCallback(async () => {
    setPhase('processing');

    try {
      let finalSegmentUri: string | null = null;

      if (phase === 'recording') {
        // Stop the current active segment
        finalSegmentUri = await stopRecording();
        segmentsRef.current = [...segmentsRef.current, finalSegmentUri];
      }

      // saveRecording uses the last file written by stopRecording internally.
      // For now, pass through the single-segment pipeline using saveRecording.
      // Multi-segment merge (Task 2C) will replace this with a merge step.
      const recordingId = await saveRecording('Inbox');

      // Clean up draft record now that recording is saved
      await deleteDraft().catch((e) =>
        console.error('RecordingScreen: Failed to delete draft after finish', e),
      );

      triggerRefresh();

      // Navigate back to inbox and then into the detail view
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
      {/* Close / Cancel button */}
      {phase !== 'processing' && (
        <Pressable
          style={styles.closeButton}
          onPress={handleCancel}
          accessibilityLabel={t('common.cancel')}
        >
          <Ionicons
            name="close"
            size={28}
            color={theme['color-basic-700']}
          />
        </Pressable>
      )}

      {phase === 'processing' ? (
        // Processing state
        <View style={styles.processingContainer}>
          <ActivityIndicator size="large" color={theme['color-primary-500']} />
          <Text
            category="s1"
            style={[styles.processingText, { color: theme['color-basic-600'] }]}
          >
            {t('recording.processing')}
          </Text>
        </View>
      ) : (
        // Active recording UI
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
            <Text
              style={[styles.timer, { color: theme['color-basic-800'] }]}
            >
              {formatDuration(totalDuration)}
            </Text>
          )}

          {/* Waveform */}
          <View style={styles.waveform}>{renderWaveform()}</View>

          {/* Primary action button — pulsing ring around the central circle */}
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

          {/* Secondary actions — only visible when paused or recording */}
          <View style={styles.buttonRow}>
            <Pressable
              style={[styles.actionButton, styles.cancelButton]}
              onPress={handleCancel}
            >
              <Text style={styles.cancelButtonText}>{t('common.cancel')}</Text>
            </Pressable>

            {(phase === 'paused') && (
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

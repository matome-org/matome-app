import { RecordingCard } from '@/processes/homeData';

export interface WaveformBar {
  height: number;
  active: boolean;
}

export interface DetailsProps {
  recording: RecordingCard;
  isLoading?: boolean;
  // Dirty / edit state (lifted to container)
  isDirty: boolean;
  isEditing: boolean;
  transcript: string;
  onTranscriptChange: (text: string) => void;
  onEditingChange: (editing: boolean) => void;
  // Audio playback
  isPlaying: boolean;
  currentTime: string;
  duration: string;
  fileSize: string;
  waveformBars: WaveformBar[];
  onPlayPause: () => void;
  // Summary
  isSummarizing?: boolean;
  onSummarize?: (text: string) => void;
  // Retry transcription
  onRetry?: () => void;
  // Notes
  onSave: () => void;
  // Navigation
  onBack: () => void;
  onMoreOptions?: () => void;
}

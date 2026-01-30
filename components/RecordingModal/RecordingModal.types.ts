export interface RecordingModalProps {
  visible: boolean;
  onClose: () => void;
  onRecordingComplete?: (recordingId: string) => void;
}

import React from "react";

export interface RecordingModalContaierProps {
  visible: boolean;
  onClose: () => void;
  onRecordingComplete?: (recordingId: string) => void;
}

export interface RecordingModalProps {
  visible: boolean;
  handleCancel: () => void;
  isProcessing: boolean;
  isRecording: boolean;
  handleStopRecording: () => void;
  handleStartRecording: () => void;
  recordingDuration: number;
  generateWaveform: () => React.JSX.Element[];
}

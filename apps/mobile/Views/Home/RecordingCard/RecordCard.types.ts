export interface RecordingCardProps {
  id: string;
  title: string;
  summary?: string;
  timestamp: string;
  duration: string;
  badge: "Work" | "Personal" | "Inbox";
  isProcessing: boolean;
  mediaType?: "audio" | "meeting" | "image";
  processingStatus?: "pending" | "processing" | "done" | "failed";
  isActive?: boolean;
  onPress?: (id: string) => void;
  onLongPress?: (id: string) => void;
  onRetry?: (id: string) => void;
  handlePress?: () => void;
  handleLongPress?: () => void;
}

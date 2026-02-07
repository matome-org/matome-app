export interface RecordingCardProps {
  id: string;
  title: string;
  summary?: string;
  timestamp: string;
  duration: string;
  badge: "Work" | "Personal" | "Inbox";
  isProcessing: boolean;
  isActive?: boolean;
  onPress?: (id: string) => void;
  handlePress?: () => void;
}


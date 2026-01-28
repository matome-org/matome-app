import { RecordingCard } from '@/processes/homeData';

export interface DetailsProps {
  recording: RecordingCard;
  isLoading?: boolean;
  onBack?: () => void;
  onSave?: (transcript: string) => void;
  onMoreOptions?: () => void;
}

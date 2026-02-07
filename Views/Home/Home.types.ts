import { HomeData } from '@/processes/homeData';

export interface HomeProps {
  data: HomeData;
  isLoading?: boolean;
  onCardPress?: (id: string) => void;
  onSearchPress?: () => void;
}

export interface RecordingCardProps {
  id: string;
  title: string;
  summary?: string;
  timestamp: string;
  duration: string;
  badge: 'Work' | 'Personal' | 'Inbox';
  isProcessing: boolean;
  isActive?: boolean;
  onPress?: (id: string) => void;
}

export interface HomeSectionProps {
  title: string;
  recordings: RecordingCardProps[];
  onCardPress?: (id: string) => void;
}

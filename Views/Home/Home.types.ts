import { HomeData } from "@/processes/homeData";
import { RecordingCardProps } from "./RecordingCard/RecordCard.types";

export interface HomeProps {
  data: HomeData;
  isLoading?: boolean;
  isRefreshing?: boolean;
  onCardPress?: (id: string) => void;
  onSearchPress?: () => void;
  onSignOutPress?: () => void;
  onRefresh?: () => void;
}

export interface HomeSectionProps {
  title: string;
  recordings: RecordingCardProps[];
  onCardPress?: (id: string) => void;
}

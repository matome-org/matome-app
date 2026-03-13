import { HomeData } from "@/processes/homeData";
import { RecordingCardProps } from "./RecordingCard/RecordCard.types";

export interface HomeProps {
  data: HomeData;
  isLoading?: boolean;
  isRefreshing?: boolean;
  isSearchOpen?: boolean;
  searchQuery?: string;
  onCardPress?: (id: string) => void;
  onCardLongPress?: (id: string) => void;
  onSearchPress?: () => void;
  onSearchChange?: (query: string) => void;
  onSearchClose?: () => void;
  onSettingsPress?: () => void;
  onRefresh?: () => void;
}

export interface HomeSectionProps {
  title: string;
  recordings: RecordingCardProps[];
  onCardPress?: (id: string) => void;
  onCardLongPress?: (id: string) => void;
}

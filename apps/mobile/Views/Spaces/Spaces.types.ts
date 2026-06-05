import { SpaceCard } from "@/processes/spacesData";

export interface SpacesProps {
  spaces: SpaceCard[];
  isLoading?: boolean;
  onSpacePress: (id: string) => void;
  onSpaceLongPress: (id: string) => void;
  onCreatePress: () => void;
}

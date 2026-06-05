import { SpaceCard } from "@/processes/spacesData";

export interface MoveToSpaceSheetProps {
  visible: boolean;
  spaces: SpaceCard[];
  onMove: (spaceId: string) => void;
  onClose: () => void;
}

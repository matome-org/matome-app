import React, { useCallback } from "react";
import RecordingCard from "./Recordingcard";
import { RecordingCardProps } from "./RecordCard.types";

const RecordingCardContainer: React.FC<RecordingCardProps> = ({
  id,
  title,
  summary,
  timestamp,
  duration,
  badge,
  isProcessing,
  isActive,
  onPress,
}) => {
  const handlePress = useCallback(() => {
    onPress?.(id);
  }, [onPress, id]);

  return (
    <RecordingCard
      id={id}
      title={title}
      summary={summary}
      timestamp={timestamp}
      duration={duration}
      badge={badge}
      isProcessing={isProcessing}
      isActive={isActive}
      onPress={onPress}
      handlePress={handlePress}
    />
  );
};

export default RecordingCardContainer;

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
  mediaType,
  processingStatus,
  isActive,
  onPress,
  onLongPress,
  onRetry,
}) => {
  const handlePress = useCallback(() => {
    onPress?.(id);
  }, [onPress, id]);

  const handleLongPress = useCallback(() => {
    onLongPress?.(id);
  }, [onLongPress, id]);

  return (
    <RecordingCard
      id={id}
      title={title}
      summary={summary}
      timestamp={timestamp}
      duration={duration}
      badge={badge}
      isProcessing={isProcessing}
      mediaType={mediaType}
      processingStatus={processingStatus}
      isActive={isActive}
      onPress={onPress}
      onLongPress={onLongPress}
      onRetry={onRetry}
      handlePress={handlePress}
      handleLongPress={handleLongPress}
    />
  );
};

export default RecordingCardContainer;

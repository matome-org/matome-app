import React, { useEffect, useState } from 'react';
import { useRouter, useLocalSearchParams } from 'expo-router';

import { fetchHomeData, RecordingCard } from '@/processes/homeData';

import { Details } from './Details';
import { DetailsProps } from './Details.types';

export const DetailsContainer: React.FC = () => {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [recording, setRecording] = useState<RecordingCard | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const loadRecording = async () => {
      try {
        setIsLoading(true);
        const homeData = await fetchHomeData();
        
        // Find the recording by ID
        let foundRecording: RecordingCard | null = null;
        for (const section of homeData.sections) {
          const found = section.recordings.find((r) => r.id === id);
          if (found) {
            foundRecording = found;
            break;
          }
        }

        if (foundRecording) {
          setRecording(foundRecording);
        } else {
          // If not found, navigate back
          router.back();
        }
      } catch (error) {
        console.error('Error loading recording:', error);
        router.back();
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      loadRecording();
    }
  }, [id, router]);

  const handleBack = () => {
    router.back();
  };

  const handleSave = (transcript: string) => {
    // In a real app, this would save the transcript
    console.log('Saving transcript:', transcript);
    // You could show a toast notification here
  };

  const handleMoreOptions = () => {
    // In a real app, this would show a menu with options
    console.log('More options pressed');
  };

  if (!recording && !isLoading) {
    return null;
  }

  const props: DetailsProps = {
    recording: recording || {
      id: '',
      title: '',
      timestamp: '',
      duration: '',
      badge: 'Inbox',
      isProcessing: false,
    },
    isLoading,
    onBack: handleBack,
    onSave: handleSave,
    onMoreOptions: handleMoreOptions,
  };

  return <Details {...props} />;
};

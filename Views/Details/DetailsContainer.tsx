import React, { useEffect, useState } from 'react';
import { useRouter, useLocalSearchParams } from 'expo-router';

import { RecordingCard } from '@/processes/homeData';
import { getRecordingById, recordToCard } from '@/services/recordingService';
import { initDatabase } from '@/utils/database';

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
        
        // Initialize database if needed
        await initDatabase();
        
        // Fetch recording directly from database
        const record = await getRecordingById(id || '');
        
        if (record) {
          const card = recordToCard(record);
          setRecording(card);
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

import { Layout, Text, useTheme } from '@ui-kitten/components';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  ScrollView,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

import { DetailsProps } from './Details.types';
import { styles } from './Details.styles';

// Mock waveform data - in a real app, this would come from audio analysis
const generateWaveform = (activeCount: number = 8) => {
  const heights = [12, 18, 24, 14, 28, 32, 20, 12, 22, 30, 16, 10, 24, 18, 12, 20, 26, 14];
  return heights.map((height, index) => ({
    height,
    active: index < activeCount,
  }));
};

export const Details: React.FC<DetailsProps> = ({
  recording,
  isLoading,
  onBack,
  onSave,
  onMoreOptions,
}) => {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const [isPlaying, setIsPlaying] = useState(false);
  const [transcript, setTranscript] = useState(recording.summary ?? '');
  const [currentTime, setCurrentTime] = useState('0:00');
  const waveform = generateWaveform(isPlaying ? 8 : 0);

  const getBadgeStyle = () => {
    if (recording.badge === 'Work') {
      return {
        backgroundColor: theme['color-primary-500'] + '26', // 15% opacity
        color: theme['color-primary-500'],
      };
    }
    return {
      backgroundColor: theme['color-basic-300'] + '26',
      color: theme['color-basic-600'],
    };
  };

  const badgeStyle = getBadgeStyle();

  const handlePlayPause = () => {
    setIsPlaying(!isPlaying);
    // In a real app, this would control audio playback
  };

  const handleSave = () => {
    onSave?.(transcript);
  };

  // Format timestamp to match template format (e.g., "Oct 24, 2023 • 09:15 AM")
  const formatDate = (timestamp: string) => {
    // For now, return a formatted version
    // In a real app, parse the timestamp properly
    const now = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const month = months[now.getMonth()];
    const day = now.getDate();
    const year = now.getFullYear();
    return `${month} ${day}, ${year} • ${timestamp}`;
  };

  if (isLoading) {
    return (
      <Layout style={[styles.container, { justifyContent: 'center', alignItems: 'center' }]}>
        <ActivityIndicator size="large" />
      </Layout>
    );
  }

  return (
    <Layout style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}>
      {/* Header */}
      <View
        style={[
          styles.header,
          {
            backgroundColor: theme['color-basic-200'],
            borderBottomColor: theme['color-basic-500'],
            paddingTop: insets.top + 16,
          },
        ]}>
        <View style={styles.headerLeft}>
          <TouchableOpacity
            onPress={onBack}
            style={[
              styles.iconButton,
              { backgroundColor: 'transparent' },
            ]}>
            <Ionicons
              name="chevron-back"
              size={24}
              color={theme['color-primary-500']}
            />
          </TouchableOpacity>
          <Text
            category="s1"
            style={[styles.headerTitle, { color: theme['color-basic-800'] }]}
            numberOfLines={1}>
            {recording.title}
          </Text>
        </View>
        <TouchableOpacity
          onPress={onMoreOptions}
          style={[
            styles.iconButton,
            { backgroundColor: 'transparent' },
          ]}>
          <Ionicons
            name="ellipsis-horizontal"
            size={24}
            color={theme['color-primary-500']}
          />
        </TouchableOpacity>
      </View>

      {/* Content */}
      <ScrollView
        style={styles.content}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 40 }}>
        {/* Meta & Workspace */}
        <View style={styles.metaRow}>
          <Text
            style={[styles.dateLabel, { color: theme['color-basic-600'] }]}>
            {formatDate(recording.timestamp)}
          </Text>
          <View
            style={[
              styles.workspaceBadge,
              {
                backgroundColor: badgeStyle.backgroundColor,
              },
            ]}>
            <Text
              style={[
                styles.workspaceBadgeText,
                { color: badgeStyle.color },
              ]}>
              {recording.badge}
            </Text>
            <Ionicons
              name="chevron-down"
              size={14}
              color={badgeStyle.color}
            />
          </View>
        </View>

        {/* Audio Player */}
        <View
          style={[
            styles.audioPlayer,
            {
              backgroundColor: theme['color-basic-100'],
              borderColor: theme['color-basic-500'],
            },
          ]}>
          <View style={styles.audioControls}>
            <TouchableOpacity
              onPress={handlePlayPause}
              style={[
                styles.playButtonLarge,
                {
                  backgroundColor: theme['color-primary-500'],
                },
              ]}>
              {isPlaying ? (
                <Ionicons
                  name="pause"
                  size={24}
                  color={theme['color-primary-900']}
                />
              ) : (
                <Ionicons
                  name="play"
                  size={24}
                  color={theme['color-primary-900']}
                />
              )}
            </TouchableOpacity>
            <View style={styles.waveformContainer}>
              {waveform.map((bar, index) => (
                <View
                  key={index}
                  style={[
                    styles.waveformBar,
                    {
                      height: bar.height,
                      backgroundColor: bar.active
                        ? theme['color-primary-500']
                        : theme['color-basic-400'],
                    },
                  ]}
                />
              ))}
            </View>
          </View>
          <View style={styles.timeDisplay}>
            <Text
              style={{
                color: theme['color-basic-600'],
                fontSize: 13,
                fontVariant: ['tabular-nums'],
              }}>
              {currentTime}
            </Text>
            <Text
              style={{
                color: theme['color-basic-600'],
                fontSize: 13,
                fontVariant: ['tabular-nums'],
              }}>
              {recording.duration}
            </Text>
          </View>
        </View>

        {/* Summary */}
        {recording.summary && (
          <View style={styles.section}>
            <View style={styles.sectionLabel}>
              <Ionicons
                name="sparkles"
                size={14}
                color={theme['color-primary-500']}
              />
              <Text
                style={[
                  styles.sectionLabel,
                  { color: theme['color-basic-600'] },
                ]}>
                Summary
              </Text>
            </View>
            <View
              style={[
                styles.summaryCard,
                {
                  backgroundColor: theme['color-basic-100'],
                  borderColor: theme['color-basic-500'],
                },
              ]}>
              <Text
                style={{
                  color: theme['color-basic-800'],
                  fontSize: 15,
                  lineHeight: 24,
                }}>
                {recording.summary}
              </Text>
            </View>
          </View>
        )}

        {/* Transcript & Notes */}
        <View style={styles.transcriptContainer}>
          <View style={styles.sectionLabel}>
            <Ionicons
              name="document-text"
              size={14}
              color={theme['color-basic-600']}
            />
            <Text
              style={[
                styles.sectionLabel,
                { color: theme['color-basic-600'] },
              ]}>
              Transcript & Notes
            </Text>
          </View>
          <TextInput
            style={[
              styles.transcriptEditor,
              {
                color: theme['color-basic-800'],
                backgroundColor: 'transparent',
              },
            ]}
            multiline
            value={transcript}
            onChangeText={setTranscript}
            placeholder="Start typing your notes..."
            placeholderTextColor={theme['color-basic-500']}
          />
        </View>
      </ScrollView>

      {/* Floating Action Button */}
      <TouchableOpacity
        onPress={handleSave}
        style={[
          styles.fab,
          {
            backgroundColor: theme['color-primary-500'],
          },
        ]}>
        <Ionicons
          name="checkmark"
          size={24}
          color={theme['color-primary-900']}
        />
      </TouchableOpacity>
    </Layout>
  );
};

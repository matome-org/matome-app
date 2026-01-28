import { Button, Layout, Text, useTheme } from '@ui-kitten/components';
import React from 'react';
import { ActivityIndicator, ScrollView, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

import { RecordingCardProps, HomeSectionProps, HomeProps } from './Home.types';
import { styles } from './Home.styles';

const RecordingCard: React.FC<RecordingCardProps> = ({
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
  const theme = useTheme();

  const handlePress = () => {
    console.log('RecordingCard pressed', id);
    onPress?.(id);
  };

  const getBadgeStyle = () => {
    if (badge === 'Work') {
      return {
        backgroundColor: theme['color-primary-500'],
        color: theme['color-primary-900'],
      };
    }
    return {
      backgroundColor: theme['color-basic-300'],
      color: theme['color-basic-700'],
    };
  };

  const badgeStyle = getBadgeStyle();

  return (
      <TouchableOpacity
        style={[
          styles.recordCard,
          {
            backgroundColor: theme['color-basic-100'],
            borderColor: theme['color-basic-500'],
          },
        ]}
        onPress={handlePress}
        >
        <View style={styles.cardIconArea}>
          <View
            style={[
              styles.playButton,
              {
                backgroundColor: isActive
                  ? theme['color-primary-500']
                  : theme['color-basic-300'],
              },
            ]}>
            {isProcessing ? (
              <ActivityIndicator
                size="small"
                color={theme['color-basic-600']}
              />
            ) : (
              <Ionicons
                name="play-outline"
                size={20}
                color={isActive
                  ? theme['color-primary-900']
                  : theme['color-basic-700']}
              />
            )}
          </View>
        </View>
        <View style={styles.cardContent}>
          <View style={styles.cardHeader}>
            <Text
              category="s1"
              style={[
                styles.cardTitle,
                { color: theme['color-basic-800'] },
              ]}
              numberOfLines={1}>
              {title}
            </Text>
            <Text
              style={[styles.metaText, { color: theme['color-basic-600'] }]}>
              {timestamp}
            </Text>
          </View>
          {isProcessing ? (
            <Text
              style={[
                styles.processingText,
                { color: theme['color-basic-600'] },
              ]}>
              Transcribing audio...
            </Text>
          ) : (
            summary && (
              <Text
                category="p2"
                style={[styles.cardSummary, { color: theme['color-basic-600'] }]}
                numberOfLines={2}>
                {summary}
              </Text>
            )
          )}
          <View style={styles.cardFooter}>
            <View
              style={[
                styles.badge,
                {
                  backgroundColor: badgeStyle.backgroundColor,
                },
                badge === 'Work' && styles.badgeWork,
                badge === 'Personal' && styles.badgePersonal,
                badge === 'Inbox' && styles.badgeInbox,
              ]}>
              <Text
                style={[
                  styles.badgeText,
                  { color: badgeStyle.color },
                ]}
                category="c1">
                {badge}
              </Text>
            </View>
            <Text
              style={[styles.metaText, { color: theme['color-basic-600'] }]}>
              {duration}
            </Text>
          </View>
        </View>
      </TouchableOpacity>
  );
};

const HomeSection: React.FC<HomeSectionProps> = ({
  title,
  recordings,
  onCardPress,
}) => {
  const theme = useTheme();

  return (
    <View>
      <Text
        style={[
          styles.sectionTitle,
          { color: theme['color-basic-600'] },
        ]}>
        {title}
      </Text>
      <View style={styles.cardList}>
        {recordings.map((recording) => (
          <RecordingCard
            key={recording.id}
            {...recording}
            onPress={onCardPress}
          />
        ))}
      </View>
    </View>
  );
};

export const Home: React.FC<HomeProps> = ({
  data,
  isLoading,
  onCardPress,
  onSearchPress,
}) => {
  const theme = useTheme();
  const insets = useSafeAreaInsets();

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
            paddingTop: insets.top + 16,
          },
        ]}>
        <Text
          category="h4"
          style={[styles.headerTitle, { color: theme['color-basic-800'] }]}>
          Inbox
        </Text>
        <Button
          appearance="ghost"
          accessoryLeft={(props) => (
            <Ionicons
              name="search-outline"
              size={20}
              color={theme['color-basic-700']}
            />
          )}
          style={[
            styles.iconButton,
            {
              backgroundColor: theme['color-basic-100'],
              borderColor: theme['color-basic-500'],
              borderWidth: 1,
            },
          ]}
          onPress={onSearchPress}
        />
      </View>

      {/* Content */}
      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {data.sections.map((section) => (
          <HomeSection
            key={section.title}
            title={section.title}
            recordings={section.recordings}
            onCardPress={onCardPress}
          />
        ))}
      </ScrollView>
    </Layout>
  );
};

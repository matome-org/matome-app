import React from 'react';
import {
  ScrollView,
  TouchableOpacity,
  View,
} from 'react-native';
import { Layout, Text, useTheme } from '@ui-kitten/components';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { styles } from './Satori.styles';

const ROADMAP = [
  { state: 'done', title: 'Full-text search across recordings', detail: 'v0.8 · shipped' },
  { state: 'active', title: 'Ask questions of your transcripts', detail: 'in progress' },
  { state: 'next', title: 'Draft emails + follow-ups from calls', detail: 'next up' },
  { state: 'next', title: 'Cross-space insights & trends', detail: 'later' },
] as const;

const ACCENT = '#E1B346';
const ACCENT_DARK = '#B98A1F';

export const Satori: React.FC = () => {
  const theme = useTheme();
  const insets = useSafeAreaInsets();

  return (
    <Layout
      style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}
    >
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingTop: insets.top + 16, paddingBottom: insets.bottom + 100 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Ambient glow blobs */}
        <View
          style={[
            styles.glowLeft,
            { backgroundColor: ACCENT + '33' },
          ]}
        />
        <View
          style={[
            styles.glowRight,
            { backgroundColor: ACCENT + '22' },
          ]}
        />

        {/* Header */}
        <View style={styles.headerRow}>
          <Text style={[styles.headerTitle, { color: theme['color-basic-800'] }]}>
            Satori
          </Text>
          <Text style={[styles.headerSubtitle, { color: theme['color-basic-600'] }]}>
            悟 · your AI assistant
          </Text>
        </View>

        {/* Medallion */}
        <View style={styles.centerContent}>
          <View style={[styles.medallion, { shadowColor: ACCENT }]}>
            <View style={styles.medallionInner}>
              <Ionicons name="sparkles" size={52} color="#fff" />
            </View>
            <View
              style={[
                styles.soonBadge,
                { backgroundColor: theme['color-basic-800'] },
              ]}
            >
              <Text style={[styles.soonText, { color: ACCENT }]}>SOON</Text>
            </View>
          </View>

          <Text
            style={[styles.ucLabel, { color: ACCENT_DARK }]}
          >
            UNDER CONSTRUCTION
          </Text>
          <Text
            style={[styles.headline, { color: theme['color-basic-800'] }]}
          >
            Satori is{' '}
            <Text style={[styles.headline, { color: ACCENT_DARK }]}>almost</Text>
            {' '}awake.
          </Text>
          <Text
            style={[styles.body, { color: theme['color-basic-600'] }]}
          >
            Your recordings, searched and understood. Ask questions, draft
            follow-ups, surface what matters. Ship target:{' '}
            <Text style={{ color: theme['color-basic-800'], fontWeight: '700' }}>
              next release
            </Text>
            .
          </Text>
        </View>

        {/* Roadmap card */}
        <View
          style={[
            styles.roadmapCard,
            {
              backgroundColor: theme['color-basic-100'],
              borderColor: theme['color-basic-500'],
            },
          ]}
        >
          <Text
            style={[styles.roadmapLabel, { color: theme['color-basic-600'] }]}
          >
            WHAT'S COMING
          </Text>

          {ROADMAP.map((item, i) => (
            <View
              key={item.title}
              style={[
                styles.roadmapRow,
                i < ROADMAP.length - 1 && {
                  borderBottomWidth: 1,
                  borderBottomColor: theme['color-basic-400'],
                },
              ]}
            >
              <View
                style={[
                  styles.roadmapDot,
                  item.state === 'done' && { backgroundColor: ACCENT, borderWidth: 0 },
                  item.state === 'active' && { borderColor: ACCENT, borderWidth: 2 },
                  item.state === 'next' && {
                    borderColor: theme['color-basic-500'],
                    borderWidth: 1.5,
                    borderStyle: 'dashed',
                  },
                ]}
              >
                {item.state === 'done' && (
                  <Ionicons name="checkmark" size={11} color={theme['color-basic-800']} />
                )}
                {item.state === 'active' && (
                  <View style={[styles.dotInner, { backgroundColor: ACCENT }]} />
                )}
              </View>
              <View style={styles.roadmapText}>
                <Text
                  style={[
                    styles.roadmapTitle,
                    {
                      color:
                        item.state === 'next'
                          ? theme['color-basic-600']
                          : theme['color-basic-800'],
                    },
                  ]}
                >
                  {item.title}
                </Text>
                <Text
                  style={[
                    styles.roadmapDetail,
                    { color: theme['color-basic-500'] },
                  ]}
                >
                  {item.detail}
                </Text>
              </View>
            </View>
          ))}
        </View>

        {/* Notify CTA */}
        <TouchableOpacity
          style={[styles.notifyButton, { backgroundColor: theme['color-basic-800'] }]}
          activeOpacity={0.85}
        >
          <Ionicons name="sparkles" size={16} color={ACCENT} />
          <Text style={styles.notifyText}>Notify me when it's ready</Text>
        </TouchableOpacity>
      </ScrollView>
    </Layout>
  );
};

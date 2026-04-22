import { Layout, Text, useTheme } from '@ui-kitten/components';
import { useTranslation } from 'react-i18next';
import { WelcomeProps } from './Welcome.types';
import { styles } from './Welcome.styles';
import { Ionicons } from '@expo/vector-icons';
import { TouchableOpacity, View, ScrollView } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const ACCENT_DARK = '#B98A1F';
const ACCENT_SOFT = '#F6E8C0';

const FEATURES = [
  {
    icon: 'mic-outline' as const,
    title: 'ワンタップ capture',
    subtitle: 'Tap once. We handle the rest.',
  },
  {
    icon: 'sparkles-outline' as const,
    title: 'AI summaries + notes',
    subtitle: 'Every recording becomes a usable artifact.',
  },
  {
    icon: 'folder-outline' as const,
    title: 'Spaces that scale',
    subtitle: 'Personal or enterprise — bring your own structure.',
  },
];

const Welcome = ({
  onLoginPress,
  onSignupPress,
}: WelcomeProps) => {
  const theme = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();

  return (
    <Layout style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingTop: insets.top + 40, paddingBottom: insets.bottom + 24 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Wordmark */}
        <View style={styles.wordmarkRow}>
          <Text style={[styles.wordmarkJP, { color: theme['color-basic-800'] }]}>
            マトメ
          </Text>
          <Text style={[styles.wordmarkEN, { color: ACCENT_DARK }]}>
            MATOME
          </Text>
        </View>

        {/* Headline */}
        <View style={styles.headlineBlock}>
          <Text style={[styles.headline, { color: theme['color-basic-800'] }]}>
            Your voice.{'\n'}
            Your life.{'\n'}
            <Text style={[styles.headlineAccent, { color: ACCENT_DARK }]}>
              Finally organized.
            </Text>
          </Text>
          <Text style={[styles.subheadline, { color: theme['color-basic-600'] }]}>
            Record, transcribe, and organize your thoughts — with Satori, your
            AI that actually listens.
          </Text>
        </View>

        {/* Features */}
        <View style={styles.featureList}>
          {FEATURES.map((f) => (
            <View key={f.title} style={styles.featureRow}>
              <View style={[styles.featureIcon, { backgroundColor: ACCENT_SOFT }]}>
                <Ionicons name={f.icon} size={22} color={ACCENT_DARK} />
              </View>
              <View style={styles.featureText}>
                <Text style={[styles.featureTitle, { color: theme['color-basic-800'] }]}>
                  {f.title}
                </Text>
                <Text style={[styles.featureSubtitle, { color: theme['color-basic-600'] }]}>
                  {f.subtitle}
                </Text>
              </View>
            </View>
          ))}
        </View>

        <View style={styles.spacer} />

        {/* CTAs */}
        <TouchableOpacity
          style={[styles.primaryBtn, { backgroundColor: theme['color-basic-800'] }]}
          onPress={onSignupPress}
          activeOpacity={0.85}
        >
          <Text style={styles.primaryBtnText}>{t('auth.createAccount')}</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.ghostBtn}
          onPress={onLoginPress}
          activeOpacity={0.75}
        >
          <Text style={[styles.ghostBtnText, { color: theme['color-basic-700'] }]}>
            Have an account?{' '}
            <Text style={[styles.ghostBtnTextBold, { color: theme['color-basic-800'] }]}>
              {t('welcome.signIn')}
            </Text>
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </Layout>
  );
};

export default Welcome;

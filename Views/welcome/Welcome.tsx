import { Button, Layout, Text, useTheme } from '@ui-kitten/components';
import { useTranslation } from 'react-i18next';
import { WelcomeProps } from './Welcome.types';
import { styles } from './Welcome.styles';

const Welcome = ({
  onLoginPress,
  onSignupPress,
}: WelcomeProps) => {
  const theme = useTheme();
  const { t } = useTranslation();

  return (
    <Layout style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}>
      <Text category="h1" style={styles.title}>{t('welcome.title')}</Text>

      <Button
        onPress={onLoginPress}
        style={styles.button}
      >
        {t('welcome.signIn')}
      </Button>

      <Button
        appearance="ghost"
        status="basic"
        onPress={onSignupPress}
      >
        {t('welcome.signUp')}
      </Button>
    </Layout>
  );
};

export default Welcome;

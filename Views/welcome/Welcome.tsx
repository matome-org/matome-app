import { Button, Layout, Text, useTheme } from '@ui-kitten/components';
import { WelcomeProps } from './Welcome.types';
import { styles } from './Welcome.styles';

const Welcome = ({
  onLoginPress,
  onSignupPress,
}: WelcomeProps) => {
  const theme = useTheme();

  return (
    <Layout style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}>
      <Text category="h1" style={styles.title}>Welcome to Matome</Text>

      <Button
        onPress={onLoginPress}
        style={styles.button}
      >
        Sign in
      </Button>

      <Button
        appearance="ghost"
        status="basic"
        onPress={onSignupPress}
      >
        Sign up
      </Button>
    </Layout>
  );
};

export default Welcome;

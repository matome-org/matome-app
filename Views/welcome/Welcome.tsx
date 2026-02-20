import { Button, Layout, Text } from '@ui-kitten/components';
import { WelcomeProps } from './Welcome.types';
import { styles } from './Welcome.styles';

const Welcome = ({
  onLoginPress,
  onSignupPress,
}: WelcomeProps) => {
  return (
    <Layout style={styles.container}>
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

import { Button, Layout, Text } from '@ui-kitten/components';
import { WelcomeProps } from './Welcome.types';
import { styles } from './Welcome.styles';

const Welcome = ({
  onLoginPress,
}: WelcomeProps) => {
  return (
    <Layout style={styles.container}>
      <Text category="h1" style={styles.title}>Bem-vindo ao App</Text>

      <Button
        onPress={onLoginPress}
        style={styles.button}
      >
        Entrar
      </Button>

      <Button
        appearance="ghost"
        status="basic"
        onPress={onLoginPress}
      >
        Cadastrar
      </Button>
    </Layout>
  );
};

export default Welcome;

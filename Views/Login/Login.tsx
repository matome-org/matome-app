import { Button, Input, Layout, Spinner, Text } from '@ui-kitten/components';
import { View } from 'react-native';
import { LoginProps } from './Login.types';
import { styles } from './Login.styles';

const LoadingIndicator = () => (
  <View style={styles.indicator}>
    <Spinner size="small" status="control" />
  </View>
);

const Login = ({
  email,
  password,
  setEmail,
  setPassword,
  onLoginPress,
  isLoading,
}: LoginProps) => {
  return (
    <Layout style={styles.container}>
      <Text category="h1" style={styles.title}>Welcome to Matome</Text>

      <Input
        style={styles.input}
        label="Email"
        value={email}
        onChangeText={setEmail}
        placeholder="Digite seu email"
        disabled={isLoading}
      />

      <Input
        style={styles.input}
        label="Senha"
        value={password}
        disabled={isLoading}
        onChangeText={setPassword}
        placeholder="Digite sua senha"
        secureTextEntry
      />

      <Button
        onPress={onLoginPress}
        accessoryLeft={isLoading ? LoadingIndicator : undefined}
        disabled={isLoading}
      >
        Entrar
      </Button>
    </Layout>
  );
};

export default Login;

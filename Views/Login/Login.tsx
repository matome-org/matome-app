import { Button, Input, Layout, Spinner, Text, useTheme } from '@ui-kitten/components';
import { KeyboardAvoidingView, Platform, ScrollView, View } from 'react-native';
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
  const theme = useTheme();

  return (
    <Layout style={[styles.container, { backgroundColor: theme['color-basic-200'] }]}>
      <KeyboardAvoidingView
        style={styles.keyboardAvoid}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Text category="h1" style={[styles.title, { color: theme["color-basic-800"] }]}>Welcome to Matome</Text>

          <Input
            style={styles.input}
            label="Email"
            value={email}
            onChangeText={setEmail}
            placeholder="Enter your email"
            autoCapitalize="none"
            keyboardType="email-address"
            disabled={isLoading}
          />

          <Input
            style={styles.input}
            label="Password"
            value={password}
            disabled={isLoading}
            onChangeText={setPassword}
            placeholder="Enter your password"
            autoCapitalize="none"
            secureTextEntry
          />

          <Button
            onPress={onLoginPress}
            accessoryLeft={isLoading ? LoadingIndicator : undefined}
            disabled={isLoading}
          >
            Sign in
          </Button>
        </ScrollView>
      </KeyboardAvoidingView>
    </Layout>
  );
};

export default Login;

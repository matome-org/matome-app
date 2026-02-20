import { Button, Input, Layout, Spinner, Text, useTheme } from '@ui-kitten/components';
import { KeyboardAvoidingView, Platform, ScrollView, View } from 'react-native';
import { SignupProps } from './Signup.types';
import { styles } from './Signup.styles';

const LoadingIndicator = () => (
  <View style={styles.indicator}>
    <Spinner size="small" status="control" />
  </View>
);

const Signup = ({
  name,
  email,
  password,
  confirmPassword,
  setName,
  setEmail,
  setPassword,
  setConfirmPassword,
  onSignupPress,
  onLoginPress,
  isLoading,
}: SignupProps) => {
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
          <Text category="h1" style={styles.title}>Create account</Text>

          <Input
            style={styles.input}
            label="Name"
            value={name}
            onChangeText={setName}
            placeholder="Enter your name"
            disabled={isLoading}
          />

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
            onChangeText={setPassword}
            placeholder="Enter your password"
            autoCapitalize="none"
            secureTextEntry
            disabled={isLoading}
          />

          <Input
            style={styles.input}
            label="Confirm password"
            value={confirmPassword}
            onChangeText={setConfirmPassword}
            placeholder="Confirm your password"
            autoCapitalize="none"
            secureTextEntry
            disabled={isLoading}
          />

          <Button
            onPress={onSignupPress}
            accessoryLeft={isLoading ? LoadingIndicator : undefined}
            disabled={isLoading}
          >
            Sign up
          </Button>

          <Button
            appearance="ghost"
            status="basic"
            style={styles.loginButton}
            onPress={onLoginPress}
            disabled={isLoading}
          >
            Already have an account? Sign in
          </Button>
        </ScrollView>
      </KeyboardAvoidingView>
    </Layout>
  );
};

export default Signup;

import { Button, Input, Layout, Spinner, Text, useTheme } from '@ui-kitten/components';
import { KeyboardAvoidingView, Platform, ScrollView, View } from 'react-native';
import { useTranslation } from 'react-i18next';
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
  const { t } = useTranslation();

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
          <Text category="h1" style={styles.title}>{t('auth.createAccount')}</Text>

          <Input
            style={styles.input}
            label={t('auth.name')}
            value={name}
            onChangeText={setName}
            placeholder={t('auth.namePlaceholder')}
            disabled={isLoading}
          />

          <Input
            style={styles.input}
            label={t('auth.email')}
            value={email}
            onChangeText={setEmail}
            placeholder={t('auth.emailPlaceholder')}
            autoCapitalize="none"
            keyboardType="email-address"
            disabled={isLoading}
          />

          <Input
            style={styles.input}
            label={t('auth.password')}
            value={password}
            onChangeText={setPassword}
            placeholder={t('auth.passwordPlaceholder')}
            autoCapitalize="none"
            secureTextEntry
            disabled={isLoading}
          />

          <Input
            style={styles.input}
            label={t('auth.confirmPassword')}
            value={confirmPassword}
            onChangeText={setConfirmPassword}
            placeholder={t('auth.confirmPasswordPlaceholder')}
            autoCapitalize="none"
            secureTextEntry
            disabled={isLoading}
          />

          <Button
            onPress={onSignupPress}
            accessoryLeft={isLoading ? LoadingIndicator : undefined}
            disabled={isLoading}
          >
            {t('welcome.signUp')}
          </Button>

          <Button
            appearance="ghost"
            status="basic"
            style={styles.loginButton}
            onPress={onLoginPress}
            disabled={isLoading}
          >
            {t('auth.alreadyHaveAccount')}
          </Button>
        </ScrollView>
      </KeyboardAvoidingView>
    </Layout>
  );
};

export default Signup;

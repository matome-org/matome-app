import { login } from '@/processes/auth';
import { useAuthStore } from '@/stores/authStore';
import { useMutation } from '@tanstack/react-query';
import { useCallback, useState } from 'react';
import Toast from 'react-native-toast-message';
import Login from './Login';

const LoginContainer = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const signIn = useAuthStore((state) => state.signIn);

    const loginMutation = useMutation({
        mutationFn: (body: { email: string; password: string }) => login(body),
        onSuccess: async () => {
            signIn();
            // Redirect is handled automatically by the auth store in _layout.tsx
        },
        onError: () => {
            Toast.show({
                type: 'error',
                text1: 'Login failed. Please try again.',
                autoHide: true,
            });
        }
    });

    const onLoginPress = useCallback(async () => {
        await loginMutation.mutateAsync({ email, password });
    }, [email, password, loginMutation]);

    return (
        <Login
            email={email}
            password={password}
            setEmail={setEmail}
            setPassword={setPassword}
            onLoginPress={onLoginPress}
            isLoading={loginMutation.isPending}
        />
    );
};

export default LoginContainer;

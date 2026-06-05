import { signup } from '@/processes/auth';
import { useMutation } from '@tanstack/react-query';
import { router } from 'expo-router';
import { useCallback, useState } from 'react';
import Toast from 'react-native-toast-message';
import Signup from './Signup';

const SignupContainer = () => {
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');

    const signupMutation = useMutation({
        mutationFn: () => signup({ email, password, name }),
        onSuccess: () => {
            Toast.show({
                type: 'success',
                text1: 'Account created!',
                text2: 'Check your email to confirm your account.',
                autoHide: true,
            });
            router.replace('/login');
        },
        onError: (error: Error) => {
            Toast.show({
                type: 'error',
                text1: 'Failed to create account',
                text2: error.message,
                autoHide: true,
            });
        },
    });

    const onSignupPress = useCallback(async () => {
        if (!name || !email || !password || !confirmPassword) {
            Toast.show({
                type: 'error',
                text1: 'Please fill in all fields',
                autoHide: true,
            });
            return;
        }

        if (password !== confirmPassword) {
            Toast.show({
                type: 'error',
                text1: 'Passwords do not match',
                autoHide: true,
            });
            return;
        }

        await signupMutation.mutateAsync();
    }, [name, email, password, confirmPassword, signupMutation]);

    const onLoginPress = useCallback(() => {
        router.replace('/login');
    }, []);

    return (
        <Signup
            name={name}
            email={email}
            password={password}
            confirmPassword={confirmPassword}
            setName={setName}
            setEmail={setEmail}
            setPassword={setPassword}
            setConfirmPassword={setConfirmPassword}
            onSignupPress={onSignupPress}
            onLoginPress={onLoginPress}
            isLoading={signupMutation.isPending}
        />
    );
};

export default SignupContainer;

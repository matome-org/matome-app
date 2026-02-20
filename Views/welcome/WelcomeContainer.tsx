import { router } from 'expo-router';
import { useCallback } from 'react';
import Welcome from './Welcome';

const WelcomeContainer = () => {
    const onLoginPress = useCallback(() => {
        router.push('/login');
    }, []);

    const onSignupPress = useCallback(() => {
        router.push('/signup');
    }, []);

    return (
        <Welcome onLoginPress={onLoginPress} onSignupPress={onSignupPress} />
    );
}

export default WelcomeContainer;
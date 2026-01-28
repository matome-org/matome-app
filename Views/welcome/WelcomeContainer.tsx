import { router } from 'expo-router';
import { useCallback } from 'react';
import Welcome from './Welcome';

const WelcomeContainer = () => {
    const onLoginPress = useCallback(() => {
        router.push('/login');
    }, []);


    return (
        <Welcome onLoginPress={onLoginPress} />
    );
}

export default WelcomeContainer;
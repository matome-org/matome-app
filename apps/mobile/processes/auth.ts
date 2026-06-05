import { coreApiClient } from '@/services/coreApiClient';
import { saveRefreshToken, saveToken } from '@/utils/storage';

import { LoginResponse, SignupResponse } from './types/authTypes';

export const login = async (body: {
    email: string;
    password: string;
}): Promise<LoginResponse> => {
    const auth = await coreApiClient.login(body);
    await saveToken(auth.access_token);
    await saveRefreshToken(auth.refresh_token);
    return auth;
};

export const signup = async (body: {
    email: string;
    password: string;
    name: string;
}): Promise<SignupResponse> => {
    const auth = await coreApiClient.register({
        email: body.email,
        password: body.password,
    });
    await saveToken(auth.access_token);
    await saveRefreshToken(auth.refresh_token);
    return auth;
};

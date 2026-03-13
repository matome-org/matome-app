import { supabase } from '@/config/supabase';

import { LoginResponse, SignupResponse } from './types/authTypes';

export const login = async (body: {
    email: string;
    password: string;
}): Promise<LoginResponse> => {
    const { data, error } = await supabase.auth.signInWithPassword(body);
    if (error) throw error;
    return data;
};

export const signup = async (body: {
    email: string;
    password: string;
    name: string;
}): Promise<SignupResponse> => {
    const { data, error } = await supabase.auth.signUp({
        email: body.email,
        password: body.password,
        options: {
            data: { name: body.name },
        },
    });
    if (error) throw error;
    return data as SignupResponse;
};

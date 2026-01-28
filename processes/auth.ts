import { patientsApi } from "@/config/api";

import { LoginResponse, SignupResponse } from "./types/authTypes";

// Temporary fake login - always returns a fake token
export const login = async (body: {
    email: string;
    password: string;
}): Promise<LoginResponse> => {
    // Simulate network delay
    await new Promise((resolve) => setTimeout(resolve, 500));
    
    // Return fake token - any email/password will work
    return {
        token: 'fake-token-' + Date.now(),
        user: {
            id: 1,
            email: body.email,
            name: 'Fake User',
        },
    } as LoginResponse;
    
    // Original API call (commented out for temporary fake login)
    // const response = await patientsApi.post<LoginResponse>('/auth/login', body);
    // return response;
};

export const signup = async (body: {
    email: string;
    password: string;
    name: string;
}): Promise<SignupResponse> => {
    const response = await patientsApi.post<SignupResponse>('/auth/register', body);
    return response;
};

import { getToken } from '@/utils/storage';
import type { AxiosRequestConfig, InternalAxiosRequestConfig } from 'axios';

export const TokenInterceptor = async (config: AxiosRequestConfig): Promise<InternalAxiosRequestConfig> => {
	const token = await getToken();

	if (token) {
		config.headers = {
			...config.headers,
			Authorization: `Bearer ${token}`,
		};
	}

	return config as InternalAxiosRequestConfig;
};

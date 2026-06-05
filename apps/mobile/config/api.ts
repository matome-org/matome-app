import axios, { AxiosError, type AxiosResponse } from 'axios';

import { configs, methods } from './config';
import { TokenInterceptor } from './interceptors';
import type { ModifiedRequests } from './types';


const apis = configs.reduce((acc, { name, ...config }) => {
	const instance = axios.create(config);

	instance.interceptors.request.use(TokenInterceptor);

	const modifiedRequests = {} as ModifiedRequests;

	methods.forEach(method => {
		modifiedRequests[method] = async <T>(
			...rest: Parameters<(typeof instance)[typeof method]>
		): Promise<T> => {
			type AxiosRequestMethod = (
				...args: Parameters<(typeof instance)[typeof method]>
			) => Promise<AxiosResponse>;

			try {
				const response = await (instance[method] as AxiosRequestMethod)(
					...rest
				);

				return (response.data.data || response.data) as T;
			} catch (err) {
				if (err instanceof AxiosError && err.response?.status === 401) {
					// handleLoginRedirect();
				}

				throw err;
			}
		};
	});

	acc[name] = {
		...instance,
		...modifiedRequests
	};

	return acc;
}, {} as Record<string, any>);

export const transcribeApi = apis.transcribeApi as Omit<typeof axios, keyof ModifiedRequests> & ModifiedRequests;

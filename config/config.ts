import type { CreateAxiosDefaults } from 'axios';
import qs from 'qs';

// import { APP_ENV } from '../env/env';
const APP_ENV = {
	PATIENTS_API_URL: 'http://localhost:3000',
	TRANSCRIBE_API_URL: 'http://localhost:8000',
};

export const methods = ['get', 'post', 'put', 'delete'] as const;

const defaultParamsSerializer = (params: any) =>
	qs.stringify(params, { arrayFormat: 'repeat', skipNulls: true });

export const configs = [{
	name: 'patientsApi' as const,
	baseURL: APP_ENV.PATIENTS_API_URL,
	paramsSerializer: defaultParamsSerializer
}, {
	name: 'transcribeApi' as const,
	baseURL: APP_ENV.TRANSCRIBE_API_URL,
}] satisfies (CreateAxiosDefaults & { name: string })[];

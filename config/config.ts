import type { CreateAxiosDefaults } from 'axios';
import qs from 'qs';

// import { APP_ENV } from '../env/env';
const APP_ENV = {
	PATIENTS_API_URL: 'http://localhost:3000',
};

export const methods = ['get', 'post', 'put', 'delete'] as const;

const defaultParamsSerializer = (params: any) =>
	qs.stringify(params, { arrayFormat: 'repeat', skipNulls: true });

export const configs = [{
	name: 'patientsApi' as const,
	baseURL: APP_ENV.PATIENTS_API_URL,
	paramsSerializer: defaultParamsSerializer
}] satisfies (CreateAxiosDefaults & { name: string })[];

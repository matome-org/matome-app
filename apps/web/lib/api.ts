import { createMatomeApiClient } from '@matome/api-client';
import { getAccessToken, getApiBaseUrl } from './session';

export const createServerApiClient = () =>
  createMatomeApiClient({
    baseUrl: getApiBaseUrl(),
    accessToken: getAccessToken,
  });

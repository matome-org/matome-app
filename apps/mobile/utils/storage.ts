import * as SecureStore from 'expo-secure-store';

const TOKEN_KEY = 'auth_token';
const REFRESH_TOKEN_KEY = 'refresh_token';

const setItem = async (key: string, value: string): Promise<void> => {
  await SecureStore.setItemAsync(key, value);
};

const getItem = async (key: string): Promise<string | null> => {
  return await SecureStore.getItemAsync(key);
};

const removeItem = async (key: string): Promise<void> => {
  await SecureStore.deleteItemAsync(key);
};

export const saveToken = async (token: string): Promise<void> => {
  await setItem(TOKEN_KEY, token);
};

export const getToken = async (): Promise<string | null> => {
  return await getItem(TOKEN_KEY);
};

export const removeToken = async (): Promise<void> => {
  await removeItem(TOKEN_KEY);
};

export const saveRefreshToken = async (token: string): Promise<void> => {
  await setItem(REFRESH_TOKEN_KEY, token);
};

export const getRefreshToken = async (): Promise<string | null> => {
  return await getItem(REFRESH_TOKEN_KEY);
};

export const removeRefreshToken = async (): Promise<void> => {
  await removeItem(REFRESH_TOKEN_KEY);
};

import type { CreateAxiosDefaults } from "axios";

// import { APP_ENV } from '../env/env';
const APP_ENV = {
  TRANSCRIBE_API_URL: "https://9cf4fd2f1fcc.ngrok-free.app",
};

export const methods = ["get", "post", "put", "delete"] as const;

export const configs = [
  {
    name: "transcribeApi" as const,
    baseURL: APP_ENV.TRANSCRIBE_API_URL,
  },
] satisfies (CreateAxiosDefaults & { name: string })[];

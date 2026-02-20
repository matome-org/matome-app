import type { CreateAxiosDefaults } from "axios";

export const methods = ["get", "post", "put", "delete"] as const;

export const configs = [
  {
    name: "transcribeApi" as const,
    baseURL: process.env.EXPO_PUBLIC_TRANSCRIBE_API_URL,
  },
] satisfies (CreateAxiosDefaults & { name: string })[];

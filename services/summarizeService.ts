import axios from "axios";
import { configs } from "@/config/config";

const transcribeConfig = configs.find(
  (c) => (c as { name?: string }).name === "transcribeApi",
);
const apiClient = transcribeConfig
  ? axios.create({ baseURL: transcribeConfig.baseURL })
  : null;

/**
 * Summarize text using the LLM summarize endpoint (POST /api/v1/summarize).
 * Returns the generated summary string.
 */
export const summarizeText = async (text: string): Promise<string> => {
  if (!apiClient) {
    throw new Error(
      "Summarize API is not configured. Check EXPO_PUBLIC_TRANSCRIBE_API_URL.",
    );
  }

  const response = await apiClient.post<{ summary: string }>(
    "/api/v1/summarize",
    { text },
    { headers: { "Content-Type": "application/json" } },
  );

  const summary = response.data?.summary;
  if (typeof summary !== "string" || !summary) {
    throw new Error("Invalid response from summarize API");
  }

  return summary;
};

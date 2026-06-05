import { createMatomeApiClient, type AuthResponse } from "../src";

const client = createMatomeApiClient({ baseUrl: "http://127.0.0.1:4000" });

async function smokeLogin(): Promise<AuthResponse> {
  return client.login({ email: "demo@example.com", password: "password" });
}

void smokeLogin;

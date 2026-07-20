import { spawn } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createV1JobServer, fetchVerifiedMedia, JobError } from "../../ai-common/src/job_service.mjs";

export const capabilities = {
  contract_version: "1",
  service: "matome-ai-audio-adapter",
  inputs: {
    audio: {
      enabled: true,
      max_bytes: 2_147_483_648,
      content_types: ["audio/wav", "audio/mpeg", "application/octet-stream"],
      outputs: ["transcript"]
    }
  }
};

export function createAiAdapterServer(options = {}) {
  const environment = options.environment ?? process.env;
  const production = options.production ?? environment.NODE_ENV === "production";
  const dataDir = options.dataDir ?? environment.AI_ADAPTER_DATA_DIR;
  const audioApiEndpoint =
    options.audioApiEndpoint ??
    environment.AUDIO_API_ENDPOINT ??
    "http://localhost:8000/api/v1/transcribe";
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;

  if (production && new URL(audioApiEndpoint).protocol !== "https:") {
    throw new Error("Production requires an HTTPS audio API endpoint.");
  }

  return createV1JobServer({
    service: "matome-ai-audio-adapter",
    capabilities,
    options: { ...options, production, dataDir, fetchImpl },
    execute: async (job) => {
      const media = await fetchVerifiedMedia(job, fetchImpl);
      const transcript = await transcribe(media, audioApiEndpoint, fetchImpl);
      return [{ type: "transcript", text: transcript }];
    }
  });
}

async function transcribe(media, audioApiEndpoint, fetchImpl) {
  const dir = await mkdtemp(join(tmpdir(), "matome-adapter-"));
  const source = join(dir, "source");
  const wav = join(dir, "audio.wav");

  try {
    await writeFile(source, media);
    await ffmpegToWav(source, wav);
    const form = new FormData();
    form.append("file", new Blob([await readFile(wav)], { type: "audio/wav" }), "audio.wav");

    let response;
    try {
      response = await fetchImpl(audioApiEndpoint, {
        method: "POST",
        body: form,
        signal: AbortSignal.timeout(30_000)
      });
    } catch (_error) {
      throw new JobError("processor_unavailable", "Audio processor is unavailable.", true);
    }

    if (!response.ok) {
      const retryable = response.status === 408 || response.status === 429 || response.status >= 500;
      throw new JobError("processor_unavailable", "Audio processor is unavailable.", retryable);
    }

    let result;
    try {
      result = await response.json();
    } catch (_error) {
      throw new JobError("invalid_processor_response", "Audio processor returned invalid data.", false);
    }

    if (typeof result.text !== "string" || Buffer.byteLength(result.text) > 4_000_000) {
      throw new JobError("invalid_processor_response", "Audio processor returned invalid data.", false);
    }
    return result.text;
  } finally {
    await rm(dir, { recursive: true, force: true }).catch(() => {});
  }
}

function ffmpegToWav(source, output) {
  return new Promise((resolve, reject) => {
    const ffmpeg = spawn(
      "ffmpeg",
      ["-y", "-i", source, "-ar", "16000", "-ac", "1", output],
      { stdio: ["ignore", "ignore", "ignore"] }
    );
    ffmpeg.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new JobError("invalid_audio", "Audio input could not be decoded.", false));
    });
    ffmpeg.on("error", () =>
      reject(new JobError("processor_unavailable", "Audio transcoder is unavailable.", true))
    );
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const host = process.env.AI_ADAPTER_HOST ?? "0.0.0.0";
  const port = Number(process.env.AI_ADAPTER_PORT ?? 7005);
  createAiAdapterServer().listen(port, host, () => {
    console.log(`Matome AI adapter listening on http://${host}:${port}`);
  });
}

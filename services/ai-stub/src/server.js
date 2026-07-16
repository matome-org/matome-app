import { createV1JobServer, fetchVerifiedMedia, JobError } from "../../ai-common/src/job_service.mjs";

export const capabilities = {
  contract_version: "1",
  service: "matome-ai-stub",
  inputs: {
    audio: {
      enabled: true,
      max_bytes: 2_147_483_648,
      content_types: ["audio/wav", "audio/mpeg"],
      outputs: ["transcript", "summary", "title"]
    },
    image: {
      enabled: true,
      max_bytes: 52_428_800,
      content_types: ["image/jpeg", "image/png"],
      outputs: ["ocr_text", "description", "summary", "title"]
    },
    document: {
      enabled: true,
      max_bytes: 524_288_000,
      content_types: ["application/pdf", "text/plain"],
      outputs: ["extracted_text", "summary", "title"]
    },
    text: {
      enabled: true,
      max_characters: 200_000,
      outputs: ["summary", "title"]
    }
  }
};

export function createAiStubServer(options = {}) {
  const environment = options.environment ?? process.env;
  const dataDir = options.dataDir ?? environment.AI_STUB_DATA_DIR;
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const forceFailure = options.forceFailure ?? booleanFromEnv(environment.AI_STUB_FORCE_FAILURE);

  return createV1JobServer({
    service: "matome-ai-stub",
    capabilities,
    options: { ...options, dataDir, fetchImpl },
    execute: async (job) => {
      if (forceFailure) {
        throw new JobError(
          "processor_unavailable",
          "Fixture processor temporarily unavailable.",
          true
        );
      }

      if (job.input.kind !== "text") await fetchVerifiedMedia(job, fetchImpl);
      return job.requested_outputs.map((type) => fixtureOutput(type, job.input.kind));
    }
  });
}

function fixtureOutput(type, kind) {
  switch (type) {
    case "transcript":
      return {
        type,
        text: "[FIXTURE] Deterministic stub transcript; no inference was performed.",
        language: "en",
        duration_ms: 42_000
      };
    case "ocr_text":
      return {
        type,
        text: "[FIXTURE] Deterministic stub OCR text; no extraction was performed.",
        language: "en"
      };
    case "description":
      return {
        type,
        text: "[FIXTURE] Deterministic stub image description; no inference was performed."
      };
    case "extracted_text":
      return {
        type,
        text: "[FIXTURE] Deterministic stub document text; no extraction was performed.",
        language: "en"
      };
    case "summary":
      return {
        type,
        markdown: `[FIXTURE] Deterministic ${kind} summary; no inference was performed.`
      };
    case "title":
      return { type, text: `[FIXTURE] ${kind} result` };
    default:
      throw new JobError("unsupported_output", "Requested output is not supported.", false);
  }
}

function booleanFromEnv(value) {
  return ["1", "true", "yes"].includes((value ?? "").toLowerCase());
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const host = process.env.AI_STUB_HOST ?? "127.0.0.1";
  const port = Number(process.env.AI_STUB_PORT ?? 7002);
  createAiStubServer().listen(port, host, () => {
    console.log(`Matome AI stub listening on http://${host}:${port}`);
  });
}

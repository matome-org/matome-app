import assert from "node:assert/strict";
import { test } from "node:test";
import { registerV1ServiceConformance } from "../../../contracts/v1/service-conformance.mjs";
import { createAiStubServer } from "./server.js";

const capabilities = {
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

registerV1ServiceConformance({
  test,
  createServer: createAiStubServer,
  capabilities,
  makeMediaBytes: async (kind) => Buffer.from(`fixture bytes for ${kind}`),
  assertOutputs: (_kind, outputs) => {
    assert.ok(
      outputs.every((output) => JSON.stringify(output).includes("[FIXTURE]")),
      "stub outputs must identify fixture simulation"
    );
  }
});

# AI engine stub (Node) — honors the engine job contract on :7002.
FROM node:22-alpine
WORKDIR /app
COPY services/ai-stub/package.json ./services/ai-stub/package.json
COPY services/ai-common/src ./services/ai-common/src
COPY services/ai-stub/src ./services/ai-stub/src
ENV AI_STUB_HOST=0.0.0.0 \
    AI_STUB_PORT=7002 \
    AI_STUB_DATA_DIR=/var/lib/matome-ai/jobs
EXPOSE 7002
CMD ["node", "services/ai-stub/src/server.js"]

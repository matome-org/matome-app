# AI adapter — bridges Core's async /v1/jobs contract to the synchronous
# whisper transcription API. Needs ffmpeg to transcode arbitrary recording
# containers (m4a/webm/mp4) to the 16k mono WAV the whisper endpoint accepts.
FROM node:20-alpine

RUN apk add --no-cache ffmpeg

WORKDIR /app
COPY services/ai-adapter/package.json ./services/ai-adapter/package.json
COPY services/ai-common/src ./services/ai-common/src
COPY services/ai-adapter/src ./services/ai-adapter/src

ENV AI_ADAPTER_HOST=0.0.0.0 \
    AI_ADAPTER_PORT=7005 \
    AI_ADAPTER_DATA_DIR=/var/lib/matome-ai/jobs

EXPOSE 7005
CMD ["node", "services/ai-adapter/src/server.js"]

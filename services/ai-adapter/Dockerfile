# AI adapter — bridges Core's async /v1/jobs contract to the synchronous
# whisper transcription API. Needs ffmpeg to transcode arbitrary recording
# containers (m4a/webm/mp4) to the 16k mono WAV the whisper endpoint accepts.
FROM node:20-alpine

RUN apk add --no-cache ffmpeg

WORKDIR /app
COPY package.json ./
# No third-party deps (Node built-ins + global fetch/FormData only), so there
# is nothing to install — copy the source and run.
COPY src ./src

ENV AI_ADAPTER_HOST=0.0.0.0 \
    AI_ADAPTER_PORT=7005

EXPOSE 7005
CMD ["node", "src/server.js"]

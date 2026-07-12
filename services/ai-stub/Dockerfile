# AI engine stub (Node) — honors the engine job contract on :7002.
FROM node:22-alpine
WORKDIR /app
COPY package.json ./
# No runtime deps declared; copy source and run.
COPY src ./src
ENV AI_STUB_HOST=0.0.0.0 \
    AI_STUB_PORT=7002
EXPOSE 7002
CMD ["node", "src/server.js"]

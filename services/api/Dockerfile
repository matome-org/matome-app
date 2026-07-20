# Core API — production OTP release for Dockploy (and any MIX_ENV=prod deploy).
# Local docker-compose continues to use Dockerfile.dev.
#
# Build:  docker build -f services/api/Dockerfile -t matome-api:prod services/api
# Run:    set env from docs/data-plane.md, then the entrypoint migrates + starts.
ARG ELIXIR_VERSION=1.17.3
ARG ERLANG_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20241202-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-debian-${DEBIAN_VERSION} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod \
    LANG=C.UTF-8

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod \
  && mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Admin LiveView assets (esbuild/tailwind) — required before release.
RUN mix assets.deploy \
  && mix compile \
  && mix release

# ── Runtime ───────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runner

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       libstdc++6 openssl libncurses5 locales ca-certificates \
       postgresql-client python3 \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen \
  && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    HOME=/app

WORKDIR /app
RUN useradd --create-home --shell /bin/bash app
USER app

COPY --from=builder --chown=app:app /app/_build/prod/rel/matome_api ./
COPY --chown=app:app docker-entrypoint.prod.sh /app/docker-entrypoint.prod.sh

USER root
RUN chmod +x /app/docker-entrypoint.prod.sh
USER app

EXPOSE 7001
ENTRYPOINT ["/app/docker-entrypoint.prod.sh"]

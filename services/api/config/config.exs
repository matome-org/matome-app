# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :matome_api,
  ecto_repos: [MatomeApi.Repo],
  generators: [timestamp_type: :utc_datetime]

config :matome_api, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, ai: 5],
  repo: MatomeApi.Repo

config :matome_api, MatomeApi.AIEngine,
  endpoint: System.get_env("AI_ENGINE_ENDPOINT") || "http://127.0.0.1:5055/v1/jobs",
  token: System.get_env("AI_ENGINE_TOKEN") || "dev-ai-token",
  callback_base_url: System.get_env("AI_ENGINE_CALLBACK_BASE_URL") || "http://127.0.0.1:4000"

config :matome_api, MatomeApi.Auth.Guardian,
  issuer: "matome_api",
  secret_key:
    System.get_env("GUARDIAN_SECRET_KEY") || "test-dev-guardian-secret-change-before-prod"

# Per-request access-token revocation (W5 #1873) — see
# docs/token-revocation.md for the full contract and rollout runbook.
#   mode: :off (dark, default) | :shadow (check + log, never rejects)
#        | :enforce (revoked/unknown sessions get 401)
#   cache: false reverts to the no-cache path (every check hits the DB)
#   cache_ttl_ms: ETS entry TTL — the bounded-staleness window for a node
#                 that misses a revocation broadcast
# NOTE: Core does not hot-reload config — changing these requires a restart.
config :matome_api, MatomeApi.Auth.TokenAllowlist,
  mode: :off,
  cache: true,
  cache_ttl_ms: 30_000

config :matome_api, MatomeApi.Storage.Presigner,
  endpoint: System.get_env("STORAGE_S3_ENDPOINT") || "http://127.0.0.1:54321/storage/v1/s3",
  access_key_id: System.get_env("STORAGE_S3_ACCESS_KEY_ID") || "test-access-key",
  secret_access_key: System.get_env("STORAGE_S3_SECRET_ACCESS_KEY") || "test-secret-key",
  region: System.get_env("STORAGE_S3_REGION") || "local",
  bucket: System.get_env("STORAGE_MEDIA_BUCKET") || "media",
  upload_expires_in: String.to_integer(System.get_env("STORAGE_UPLOAD_URL_TTL") || "900"),
  download_expires_in: String.to_integer(System.get_env("STORAGE_DOWNLOAD_URL_TTL") || "300")

# CORS allowed origins for browser clients (Flutter Web).
# Overridden at runtime via CORS_ORIGINS (comma-separated) in runtime.exs.
# Defaults cover the `mise run flutter-web` dev origin (port 8080). For prod
# set CORS_ORIGINS explicitly.
config :matome_api,
       :cors_origins,
       System.get_env("CORS_ORIGINS") ||
         "http://localhost:8080,http://127.0.0.1:8080"

# Configures the endpoint
config :matome_api, MatomeApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: MatomeApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MatomeApi.PubSub,
  live_view: [signing_salt: "da57Xt5Q"]

# Asset pipeline for the /admin back-office (plan p2-core-backoffice, W0
# #1868). esbuild bundles the LiveView JS; Tailwind builds the CSS. Both are
# dev-time tools (runtime: false in prod) — only the compiled priv/static
# artifacts ship. `version` mirrors the binaries seeded under _build; a
# networked env installs them via `mix assets.setup`.
config :esbuild,
  version: "0.17.11",
  matome: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Tailwind v4 (CSS-first config; the theme lives in assets/css/app.css via
# `@theme`, sourced from the hand-maintained foundations token file).
config :tailwind,
  version: "4.1.5",
  matome: [
    args: ~w(--input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Redact PII / secrets from any logged request params (#1462). Phoenix's
# default only filters "password"; contact email/phone are PII and must never
# reach logs or telemetry payloads.
config :phoenix, :filter_parameters, ["password", "email", "phone"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Transactional email (Swoosh). Default/dev uses the Local adapter (preview at
# /dev/mailbox); swap `adapter:` per environment (config/runtime.exs for prod) to
# plug a real provider (Mailgun/SES/SMTP/...) without touching call sites.
config :matome_api, MatomeApi.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh only needs an HTTP api_client for API-based adapters; disable it here.
config :swoosh, :api_client, false

import_config "#{config_env()}.exs"

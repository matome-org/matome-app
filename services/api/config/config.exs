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

config :matome_api, MatomeApi.Storage.Presigner,
  endpoint: System.get_env("STORAGE_S3_ENDPOINT") || "http://127.0.0.1:54321/storage/v1/s3",
  access_key_id: System.get_env("STORAGE_S3_ACCESS_KEY_ID") || "test-access-key",
  secret_access_key: System.get_env("STORAGE_S3_SECRET_ACCESS_KEY") || "test-secret-key",
  region: System.get_env("STORAGE_S3_REGION") || "local",
  bucket: System.get_env("STORAGE_MEDIA_BUCKET") || "media",
  upload_expires_in: String.to_integer(System.get_env("STORAGE_UPLOAD_URL_TTL") || "900"),
  download_expires_in: String.to_integer(System.get_env("STORAGE_DOWNLOAD_URL_TTL") || "300")

# CORS allowed origins for browser clients (Flutter Web, etc.).
# Overridden at runtime via CORS_ORIGINS (comma-separated) in runtime.exs.
# Defaults below cover the common dev origins for `flutter run -d chrome`
# (Flutter picks an ephemeral port unless --web-port is passed) plus the
# Next.js web client. For prod set CORS_ORIGINS explicitly.
config :matome_api, :cors_origins,
  System.get_env("CORS_ORIGINS") ||
    "http://localhost:8080,http://127.0.0.1:8080,http://localhost:3000,http://127.0.0.1:3000"

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

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

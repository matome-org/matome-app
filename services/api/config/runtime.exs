import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/matome_api start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :matome_api, MatomeApiWeb.Endpoint, server: true
end

# Allow CORS origins to be overridden at runtime in any environment.
# Comma-separated list, e.g. "https://app.matome.test,https://web.matome.test".
if origins = System.get_env("CORS_ORIGINS") do
  config :matome_api, :cors_origins, origins
end

config :matome_api, MatomeApi.AIEngine,
  endpoint: System.get_env("AI_ENGINE_ENDPOINT") || "http://127.0.0.1:5055/v1/jobs",
  token: System.get_env("AI_ENGINE_TOKEN") || "dev-ai-token",
  callback_base_url: System.get_env("AI_ENGINE_CALLBACK_BASE_URL") || "http://127.0.0.1:4000"

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
  ssl = System.get_env("DATABASE_SSL", "true") in ~w(true 1)

  config :matome_api, MatomeApi.Repo,
    url: database_url,
    ssl: ssl,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  guardian_secret_key =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise """
      environment variable GUARDIAN_SECRET_KEY is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :matome_api, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :matome_api, MatomeApi.Auth.Guardian, secret_key: guardian_secret_key

  storage_s3_endpoint =
    System.get_env("STORAGE_S3_ENDPOINT") ||
      raise "environment variable STORAGE_S3_ENDPOINT is missing."

  storage_s3_access_key_id =
    System.get_env("STORAGE_S3_ACCESS_KEY_ID") ||
      raise "environment variable STORAGE_S3_ACCESS_KEY_ID is missing."

  storage_s3_secret_access_key =
    System.get_env("STORAGE_S3_SECRET_ACCESS_KEY") ||
      raise "environment variable STORAGE_S3_SECRET_ACCESS_KEY is missing."

  config :matome_api, MatomeApi.Storage.Presigner,
    endpoint: storage_s3_endpoint,
    access_key_id: storage_s3_access_key_id,
    secret_access_key: storage_s3_secret_access_key,
    region: System.get_env("STORAGE_S3_REGION") || "local",
    bucket: System.get_env("STORAGE_MEDIA_BUCKET") || "media",
    upload_expires_in: String.to_integer(System.get_env("STORAGE_UPLOAD_URL_TTL") || "900"),
    download_expires_in: String.to_integer(System.get_env("STORAGE_DOWNLOAD_URL_TTL") || "300")

  config :matome_api, MatomeApiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :matome_api, MatomeApiWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :matome_api, MatomeApiWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end

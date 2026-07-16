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

# Bind the HTTP listener to a specific IP at runtime (all environments). The
# dev default is loopback ({127,0,0,1}); inside a container that is unreachable
# from the host / sibling services, so `PHX_HTTP_IP=0.0.0.0` (Docker) opens all
# interfaces. Deep-merges into the endpoint's `http:` keyword, so `port` and the
# rest of the dev/prod config are preserved. Absent ⇒ unchanged loopback.
if ip = System.get_env("PHX_HTTP_IP") do
  parsed_ip =
    ip |> String.split(".") |> Enum.map(&String.to_integer/1) |> List.to_tuple()

  config :matome_api, MatomeApiWeb.Endpoint, http: [ip: parsed_ip]
end

ai_dispatch_token =
  System.get_env("AI_ENGINE_DISPATCH_TOKEN") ||
    if(config_env() == :prod,
      do: raise("AI_ENGINE_DISPATCH_TOKEN is required in production"),
      else: "dev-ai-dispatch-token"
    )

ai_callback_signing_secret =
  System.get_env("AI_ENGINE_CALLBACK_SIGNING_SECRET") ||
    if(config_env() == :prod,
      do: raise("AI_ENGINE_CALLBACK_SIGNING_SECRET is required in production"),
      else: "dev-ai-callback-signing-secret"
    )

if ai_dispatch_token == ai_callback_signing_secret do
  raise "AI dispatch and callback credentials must be different"
end

if config_env() == :prod and
     (byte_size(ai_dispatch_token) < 32 or byte_size(ai_callback_signing_secret) < 32) do
  raise "AI dispatch and callback credentials must each be at least 32 bytes"
end

ai_engine_endpoint =
  System.get_env("AI_ENGINE_ENDPOINT") || "http://127.0.0.1:7002/v1/jobs"

ai_callback_base_url =
  System.get_env("AI_ENGINE_CALLBACK_BASE_URL") || "http://127.0.0.1:7001"

if config_env() == :prod do
  for {name, value} <- [
        {"AI_ENGINE_ENDPOINT", ai_engine_endpoint},
        {"AI_ENGINE_CALLBACK_BASE_URL", ai_callback_base_url}
      ] do
    uri = URI.parse(value)

    if uri.scheme != "https" or not is_binary(uri.host) do
      raise "#{name} must be an absolute HTTPS URL in production"
    end
  end
end

config :matome_api, MatomeApi.AIEngine,
  endpoint: ai_engine_endpoint,
  dispatch_token: ai_dispatch_token,
  callback_signing_secret: ai_callback_signing_secret,
  callback_base_url: ai_callback_base_url

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
  port = String.to_integer(System.get_env("PORT") || "7001")

  config :matome_api, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :matome_api, MatomeApi.Auth.Guardian, secret_key: guardian_secret_key

  parse_csv = fn env_var ->
    (System.get_env(env_var) || "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # /admin email-OTP gate. Panel is OFF unless ADMIN_PANEL_ENABLED=true.
  # Identity = ADMIN_EMAIL_ALLOWLIST (CSV). Soft ADMIN_IP_ALLOWLIST only
  # tiers rate limits — empty means every IP may reach the panel.
  config :matome_api, :admin_panel,
    enabled: System.get_env("ADMIN_PANEL_ENABLED") in ~w(true 1),
    email_allowlist: parse_csv.("ADMIN_EMAIL_ALLOWLIST")

  config :matome_api, :admin_network,
    allowlist: parse_csv.("ADMIN_IP_ALLOWLIST"),
    trusted_proxies: parse_csv.("ADMIN_TRUSTED_PROXIES")

  config :matome_api, :admin_session,
    ttl_seconds: String.to_integer(System.get_env("ADMIN_SESSION_TTL_SECONDS") || "1800"),
    reauth_ttl_seconds: String.to_integer(System.get_env("ADMIN_REAUTH_TTL_SECONDS") || "300")

  admin_otp_pepper =
    System.get_env("ADMIN_OTP_PEPPER") ||
      raise "environment variable ADMIN_OTP_PEPPER is missing."

  if byte_size(admin_otp_pepper) < 32 do
    raise "ADMIN_OTP_PEPPER must contain at least 32 bytes."
  end

  config :matome_api, :admin_otp, pepper: admin_otp_pepper

  # Optional leftover vault (TOTP path retired). Present only if set.
  if vault = System.get_env("ADMIN_SECRET_VAULT_KEY") do
    config :matome_api, MatomeApi.Admin.SecretVault, key: vault
  end

  # Transactional email — Local is never used in prod.
  # Mailgun needs an HTTP client on the classpath (`:hackney` or Finch);
  # add the dep in the deploy image when enabling mailgun.
  case System.get_env("MAILER_ADAPTER") do
    "mailgun" ->
      config :matome_api, MatomeApi.Mailer,
        adapter: Swoosh.Adapters.Mailgun,
        api_key: System.get_env("MAILGUN_API_KEY") || raise("MAILGUN_API_KEY is missing."),
        domain: System.get_env("MAILGUN_DOMAIN") || raise("MAILGUN_DOMAIN is missing.")

      config :swoosh, api_client: Swoosh.ApiClient.Hackney

    "smtp" ->
      config :matome_api, MatomeApi.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: System.get_env("SMTP_RELAY") || raise("SMTP_RELAY is missing."),
        username: System.get_env("SMTP_USERNAME"),
        password: System.get_env("SMTP_PASSWORD"),
        ssl: System.get_env("SMTP_SSL", "true") in ~w(true 1),
        tls: :always,
        auth: :always,
        port: String.to_integer(System.get_env("SMTP_PORT") || "587")

    other when other in [nil, "", "local"] ->
      raise """
      production requires MAILER_ADAPTER=mailgun or smtp (Local is disabled).
      """

    other ->
      raise "unsupported MAILER_ADAPTER=#{inspect(other)} (use mailgun or smtp)"
  end

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
    server_endpoint: System.get_env("STORAGE_S3_INTERNAL_ENDPOINT") || storage_s3_endpoint,
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

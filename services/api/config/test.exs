import Config

repo_config =
  if database_url = System.get_env("DATABASE_URL") do
    [
      url: database_url,
      ssl: System.get_env("DATABASE_SSL", "false") in ~w(true 1)
    ]
  else
    [
      username: "postgres",
      password: "postgres",
      hostname: "localhost",
      database: "matome_api_test#{System.get_env("MIX_TEST_PARTITION")}"
    ]
  end

# Configure your database. DATABASE_URL points at native/local Postgres
# (e.g. postgres://postgres@127.0.0.1:7020/matome_api_test from mise up).
config :matome_api,
       MatomeApi.Repo,
       Keyword.merge(repo_config,
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: System.schedulers_online() * 2
       )

config :matome_api, Oban,
  testing: :manual,
  queues: false,
  plugins: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :matome_api, MatomeApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "9A8u6B/N6i9CaYNIawv9aJ7p4LNHWTRiL69YTa1zuOFvaDB/x2aNThjuni/jZlot",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Capture outgoing email in-memory so tests can assert on deliveries.
config :matome_api, MatomeApi.Mailer, adapter: Swoosh.Adapters.Test

# Leftover vault key (TOTP path retired from login).
config :matome_api, MatomeApi.Admin.SecretVault,
  key: Base.encode64("test-only-admin-vault-key32bytes")

config :matome_api, :admin_panel,
  enabled: true,
  email_allowlist: ["admin@example.com"]

# Soft IP tier empty by default (all IPs normal rate limits).
config :matome_api, :admin_network,
  allowlist: [],
  trusted_proxies: []

config :matome_api, :admin_session, ttl_seconds: 30 * 60, reauth_ttl_seconds: 5 * 60

config :matome_api, MatomeApi.Storage.ObjectStore, adapter: MatomeApi.Storage.ObjectStore.Noop

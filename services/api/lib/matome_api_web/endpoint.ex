defmodule MatomeApiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :matome_api

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_matome_api_key",
    signing_salt: "Wlk16YV3",
    same_site: "Lax"
  ]

  socket "/socket", MatomeApiWeb.UserSocket,
    websocket: true,
    longpoll: false

  # LiveView socket for the /admin back-office (W0 #1868).
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :matome_api,
    gzip: false,
    only: MatomeApiWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :matome_api
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # CORS must run before the router so browser preflight (OPTIONS) requests
  # and Authorization headers from cross-origin clients (Flutter Web) are
  # handled. Allowed origins come from the :cors_origins app env (configurable
  # via CORS_ORIGINS); see config/config.exs and config/runtime.exs.
  plug CORSPlug,
    origin: &MatomeApiWeb.Endpoint.cors_origins/0,
    headers: [
      "Authorization",
      "Content-Type",
      "Accept",
      "Origin",
      "X-Requested-With"
    ],
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

  plug OpenApiSpex.Plug.PutApiSpec, module: MatomeApiWeb.ApiSpec
  plug MatomeApiWeb.Router

  @doc """
  Returns the list of allowed CORS origins, sourced from the
  `:matome_api, :cors_origins` application env (a comma-separated string).
  Evaluated per-request so runtime config (CORS_ORIGINS) is honoured.
  """
  def cors_origins do
    Application.get_env(:matome_api, :cors_origins, "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end

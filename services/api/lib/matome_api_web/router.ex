defmodule MatomeApiWeb.Router do
  use MatomeApiWeb, :router

  import PhoenixStorybook.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Server-rendered HTML pipeline for the /admin back-office (W0 #1868). The
  # JSON API pipelines above are untouched — admin is an additive surface.
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MatomeApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug MatomeApiWeb.Plugs.RequireAuth
  end

  pipeline :internal_auth do
    plug MatomeApiWeb.Plugs.RequireInternalToken
  end

  # Task #1854 (plan #131 W3) — the pre-auth salt bootstrap (CF-1): a user
  # who forgot their password has no session, so the normal :auth pipeline
  # is unreachable. This pipeline authenticates with the reset token instead
  # (proof of email ownership), scoped ONLY to the /keybundle/recovery
  # routes below.
  pipeline :require_reset_token do
    plug MatomeApiWeb.Plugs.RequireResetToken
  end

  # Anti credential-stuffing on the public auth endpoints: a per-IP limit
  # (blunt volumetric defense) plus a per-account limit keyed on the
  # `email` param (the actual lockout — a compromised/crackable wrapped
  # envelope is useless to an attacker who can't also brute-force the
  # login credential past this).
  pipeline :auth_rate_limit do
    plug MatomeApiWeb.Plugs.RateLimit,
      scope: :auth,
      checks: [
        {:ip, limit: 60, window_ms: 60_000, lockout_ms: 60_000},
        {{:param, "email"}, limit: 5, window_ms: 60_000, lockout_ms: 300_000}
      ]
  end

  # Same idea for GET /keybundle: an offline attacker who dumps the
  # opaque bundle store still cannot decrypt it, but the endpoint itself
  # must not become a low-cost oracle for enumerating/hammering accounts.
  pipeline :keybundle_get_rate_limit do
    plug MatomeApiWeb.Plugs.RateLimit,
      scope: :keybundle_get,
      checks: [
        {:user, limit: 10, window_ms: 60_000, lockout_ms: 300_000},
        {:ip, limit: 30, window_ms: 60_000, lockout_ms: 60_000}
      ]
  end

  # Task #1854, plan #131 W3 — same idea as :keybundle_get_rate_limit, applied
  # to the pre-auth recovery bootstrap routes: a leaked/guessed reset token
  # must not become a low-cost oracle for hammering an account's key bundle.
  pipeline :keybundle_recovery_rate_limit do
    plug MatomeApiWeb.Plugs.RateLimit,
      scope: :keybundle_recovery,
      checks: [
        {:user, limit: 5, window_ms: 60_000, lockout_ms: 300_000},
        {:ip, limit: 20, window_ms: 60_000, lockout_ms: 60_000}
      ]
  end

  # okt-audit AUDIT-CORE (task #1865): PUT /keybundle is an authenticated
  # write, so a stolen/guessed access token still shouldn't get unlimited,
  # rate-limit-free attempts at overwriting the bundle — every other
  # keybundle route (GET here, GET/PUT under /recovery) already carries a
  # rate-limit pipeline; this closes the one gap left uncovered (DoS-oracle
  # asymmetry). Same shape/numbers as :keybundle_get_rate_limit.
  pipeline :keybundle_put_rate_limit do
    plug MatomeApiWeb.Plugs.RateLimit,
      scope: :keybundle_put,
      checks: [
        {:user, limit: 10, window_ms: 60_000, lockout_ms: 300_000},
        {:ip, limit: 30, window_ms: 60_000, lockout_ms: 60_000}
      ]
  end

  get "/health", MatomeApiWeb.HealthController, :show
  get "/openapi", OpenApiSpex.Plug.RenderSpec, []

  scope "/api", MatomeApiWeb do
    pipe_through [:api, :auth_rate_limit]

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
    post "/auth/forgot-password", AuthController, :forgot_password
    post "/auth/reset-password", AuthController, :reset_password
  end

  scope "/api", MatomeApiWeb do
    pipe_through :api

    scope "/auth" do
      pipe_through :auth

      get "/me", AuthController, :me
    end

    scope "/" do
      pipe_through [:auth, :keybundle_get_rate_limit]

      get "/keybundle", KeyBundleController, :show
    end

    # Task #1854, plan #131 W3 — pre-auth recovery bootstrap (CF-1). Reuses
    # the SAME KeyBundleController actions as the authenticated /keybundle
    # routes above (every field is an opaque blob regardless of which auth
    # channel fetched/stored it); only the auth pipeline differs.
    scope "/" do
      pipe_through [:require_reset_token, :keybundle_recovery_rate_limit]

      get "/keybundle/recovery", KeyBundleController, :show
      put "/keybundle/recovery", KeyBundleController, :upsert
    end

    scope "/" do
      pipe_through [:auth, :keybundle_put_rate_limit]

      put "/keybundle", KeyBundleController, :upsert
    end

    scope "/" do
      pipe_through :auth

      get "/spaces/search", WorkspaceController, :search
      resources "/spaces", WorkspaceController, except: [:new, :edit]

      get "/matomes/search", MatomeController, :search
      post "/matomes/:id/archive", MatomeController, :archive
      post "/matomes/:id/restore", MatomeController, :restore
      post "/matomes/:matome_id/contacts", MatomeController, :attach_contact
      delete "/matomes/:matome_id/contacts/:contact_id", MatomeController, :detach_contact
      get "/matomes/:matome_id/items", ItemController, :index
      post "/matomes/:matome_id/items", ItemController, :create
      resources "/matomes", MatomeController, except: [:new, :edit]

      get "/items", ItemController, :index
      get "/items/:id", ItemController, :show
      patch "/items/:id", ItemController, :update
      post "/items/:id/presign", ItemController, :presign
      get "/items/:id/download-url", ItemController, :download_url
      post "/items/:id/process", ItemController, :process
      delete "/items/:id", ItemController, :delete

      get "/contacts/search", ContactController, :search
      resources "/contacts", ContactController, except: [:new, :edit]
    end
  end

  scope "/internal", MatomeApiWeb do
    pipe_through [:api, :internal_auth]

    post "/jobs/:id/result", InternalJobController, :result
  end

  # ── /admin defense-in-depth gate (plan p2-core-backoffice §9.1, W3 #1871) ──
  #
  # Layer order is deliberate: network guard FIRST (outside the allowlist the
  # back-office does not even exist — 404), then the browser stack, then the
  # session gate (password + mandatory TOTP, short absolute TTL). Sensitive
  # actions in later waves additionally mount
  # `MatomeApiWeb.Plugs.RequireRecentTotp` for per-action re-auth.

  pipeline :admin_network do
    plug MatomeApiWeb.Plugs.AdminNetworkGuard
  end

  pipeline :admin_auth do
    plug MatomeApiWeb.Plugs.RequireAdminSession
  end

  # Anti brute-force on the admin first factor, same shape as :auth_rate_limit.
  pipeline :admin_login_rate_limit do
    plug MatomeApiWeb.Plugs.RateLimit,
      scope: :admin_login,
      checks: [
        {:ip, limit: 30, window_ms: 60_000, lockout_ms: 60_000},
        {{:param, "email"}, limit: 5, window_ms: 60_000, lockout_ms: 300_000}
      ]
  end

  scope "/admin", MatomeApiWeb do
    pipe_through [:browser, :admin_network]

    get "/login", AdminSessionController, :new
    get "/mfa", AdminSessionController, :mfa
    post "/mfa", AdminSessionController, :verify_mfa
    post "/logout", AdminSessionController, :delete
  end

  scope "/admin", MatomeApiWeb do
    pipe_through [:browser, :admin_network, :admin_login_rate_limit]

    post "/login", AdminSessionController, :create
  end

  scope "/admin", MatomeApiWeb do
    pipe_through [:browser, :admin_network, :admin_auth]

    # `on_mount` re-checks session AND network on the CONNECTED mount — the
    # websocket upgrade bypasses these router pipelines (see AdminAuth).
    live_session :admin, on_mount: [{MatomeApiWeb.AdminAuth, :require_admin}] do
      live "/", AdminLive.Index, :index
    end
  end

  # Design-system catalog (plan p2-core-backoffice, Phase A) — the Elixir
  # equivalent of the Flutter Widgetbook, rendering the real HEEx base +
  # composite components as a browsable drift-guard gallery.
  #
  # Compile-gated on `:dev_routes` (true only in dev/test config) so the mount
  # is provably ABSENT from a :prod release — a stronger guarantee than a
  # runtime check, and the reason phoenix_storybook can be a normal dep without
  # ever exposing an arbitrary-render surface in production.
  if Application.compile_env(:matome_api, :dev_routes) do
    scope "/" do
      storybook_assets()
    end

    scope "/", MatomeApiWeb do
      pipe_through :browser

      live_storybook "/storybook", backend_module: MatomeApiWeb.Storybook
    end
  end
end

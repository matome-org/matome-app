defmodule MatomeApiWeb.Router do
  use MatomeApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug MatomeApiWeb.Plugs.RequireAuth
  end

  pipeline :internal_auth do
    plug MatomeApiWeb.Plugs.RequireInternalToken
  end

  get "/health", MatomeApiWeb.HealthController, :show
  get "/openapi", OpenApiSpex.Plug.RenderSpec, []

  scope "/api", MatomeApiWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout

    scope "/auth" do
      pipe_through :auth

      get "/me", AuthController, :me
    end

    scope "/" do
      pipe_through :auth

      get "/spaces/search", WorkspaceController, :search
      resources "/spaces", WorkspaceController, except: [:new, :edit]

      get "/recordings/search", RecordingController, :search
      get "/recordings/:id/download-url", RecordingController, :download_url
      post "/recordings/:id/process", RecordingController, :process
      resources "/recordings", RecordingController, except: [:new, :edit]

      get "/matomes/search", MatomeController, :search
      post "/matomes/:id/archive", MatomeController, :archive
      post "/matomes/:id/restore", MatomeController, :restore
      post "/matomes/:matome_id/contacts", MatomeController, :attach_contact
      delete "/matomes/:matome_id/contacts/:contact_id", MatomeController, :detach_contact
      resources "/matomes", MatomeController, except: [:new, :edit]

      get "/contacts/search", ContactController, :search
      resources "/contacts", ContactController, except: [:new, :edit]
    end
  end

  scope "/internal", MatomeApiWeb do
    pipe_through [:api, :internal_auth]

    post "/jobs/:id/result", InternalJobController, :result
  end
end

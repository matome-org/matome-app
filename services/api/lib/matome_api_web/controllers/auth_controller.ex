defmodule MatomeApiWeb.AuthController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Admin.NetworkPolicy
  alias MatomeApi.Auth

  import MatomeApiWeb.ChangesetErrors, only: [errors_on: 1]

  def register(conn, params) do
    case Auth.register_user(params, session_meta(conn, params, "register")) do
      {:ok, auth} ->
        conn |> put_status(:created) |> json(auth_response(auth))

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  # New wire shape (task #1852): a migrated client derives
  # auth_secret = Argon2id(password, salt_auth) client-side and sends that
  # instead of the raw password. This clause and the legacy `password` one
  # below are both served during the additive rollout so an un-migrated
  # client is never locked out; the `password` clause is scheduled for a
  # later, separately-tracked subtractive drop.
  def login(conn, %{"email" => email, "auth_secret" => auth_secret} = params) do
    case Auth.login(email, auth_secret, session_meta(conn, params, "auth_secret")) do
      {:ok, auth} ->
        json(conn, auth_response(auth))

      {:error, :invalid_credentials} ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid_credentials"})
    end
  end

  def login(conn, %{"email" => email, "password" => password} = params) do
    case Auth.login(email, password, session_meta(conn, params, "password")) do
      {:ok, auth} ->
        json(conn, auth_response(auth))

      {:error, :invalid_credentials} ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid_credentials"})
    end
  end

  def login(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "email_and_password_required"})
  end

  def refresh(conn, %{"refresh_token" => refresh_token} = params) do
    # No login_method here: a refresh continues an existing session, so the
    # method (and device) are inherited from the rotated token in the context.
    case Auth.refresh(refresh_token, session_meta(conn, params, nil)) do
      {:ok, auth} ->
        json(conn, auth_response(auth))

      {:error, :invalid_refresh_token} ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid_refresh_token"})
    end
  end

  def refresh(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "refresh_token_required"})
  end

  def logout(conn, params) do
    Auth.logout(params["refresh_token"])
    send_resp(conn, :no_content, "")
  end

  def forgot_password(conn, %{"email" => email}) do
    # Always 200 with the same body — never reveal whether the email exists.
    Auth.request_password_reset(email)
    json(conn, %{status: "ok"})
  end

  def forgot_password(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "email_required"})
  end

  def reset_password(conn, %{"token" => token, "password" => password} = params) do
    case Auth.reset_password(token, password, session_meta(conn, params, "password_reset")) do
      {:ok, auth} ->
        json(conn, auth_response(auth))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})

      {:error, :invalid_reset_token} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid_reset_token"})
    end
  end

  def reset_password(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "token_and_password_required"})
  end

  def me(conn, _params) do
    json(conn, %{user: user_response(conn.assigns.current_user)})
  end

  defp auth_response(%{user: user, access_token: access_token, refresh_token: refresh_token}) do
    %{
      user: user_response(user),
      access_token: access_token,
      refresh_token: refresh_token,
      token_type: "Bearer"
    }
  end

  defp user_response(user), do: %{id: user.id, email: user.email}

  # Session-metadata capture (W4 #1872): what the token/device rows record
  # about this request. The client may additionally describe itself with an
  # optional `device` object (`id` = stable client-generated UUID used for
  # correlation, plus `platform`/`display_name`).
  defp session_meta(conn, params, login_method) do
    %{
      ip: client_ip(conn),
      user_agent: conn |> get_req_header("user-agent") |> List.first(),
      device: device_params(params),
      login_method: login_method
    }
  end

  defp device_params(%{"device" => %{} = device}), do: device
  defp device_params(_params), do: nil

  # Reuses the W3 trusted-proxy resolution (NetworkPolicy) instead of
  # re-deriving X-Forwarded-For handling: the header only participates when
  # the direct peer is a pinned trusted proxy; otherwise the peer itself is
  # the client. An unresolvable chain records nothing rather than attacker
  # input.
  defp client_ip(conn) do
    case NetworkPolicy.client_ip(conn.remote_ip, get_req_header(conn, "x-forwarded-for")) do
      {:ok, ip} -> ip |> :inet.ntoa() |> to_string()
      :error -> nil
    end
  end
end

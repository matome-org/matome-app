defmodule MatomeApiWeb.AuthController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Auth

  def register(conn, params) do
    case Auth.register_user(params) do
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
  def login(conn, %{"email" => email, "auth_secret" => auth_secret}) do
    case Auth.login(email, auth_secret) do
      {:ok, auth} ->
        json(conn, auth_response(auth))

      {:error, :invalid_credentials} ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid_credentials"})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Auth.login(email, password) do
      {:ok, auth} ->
        json(conn, auth_response(auth))

      {:error, :invalid_credentials} ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid_credentials"})
    end
  end

  def login(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "email_and_password_required"})
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Auth.refresh(refresh_token) do
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

  def reset_password(conn, %{"token" => token, "password" => password}) do
    case Auth.reset_password(token, password) do
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

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

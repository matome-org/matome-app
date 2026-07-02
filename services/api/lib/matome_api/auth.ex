defmodule MatomeApi.Auth do
  import Ecto.Query

  alias MatomeApi.Auth.{Guardian, RefreshToken, User}
  alias MatomeApi.Repo

  @access_ttl {15, :minutes}
  @refresh_ttl {30, :days}
  @reset_ttl {30, :minutes}

  def get_user(id), do: Repo.get(User, id)

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> with_tokens()
  end

  def login(email, password) do
    user = Repo.get_by(User, email: String.downcase(email || ""))

    cond do
      user && Argon2.verify_pass(password || "", user.password_hash) -> with_tokens({:ok, user})
      true -> {:error, :invalid_credentials}
    end
  end

  @doc """
  Starts the password-reset flow. Always returns `:ok` regardless of whether the
  email matches an account, so callers cannot use it to enumerate users. When a
  user exists, a short-lived Guardian `reset` token is minted and emailed.
  """
  def request_password_reset(email) do
    email = String.downcase(email || "")

    case Repo.get_by(User, email: email) do
      %User{} = user ->
        {:ok, reset_token, _claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "reset", ttl: @reset_ttl)

        MatomeApi.Auth.UserNotifier.deliver_reset_password(user, reset_token)
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Completes a password reset: verifies the `reset` token, sets the new password,
  revokes all existing refresh tokens for that user, and issues a fresh session.
  Returns `{:ok, auth}`, `{:error, %Ecto.Changeset{}}` (weak password), or
  `{:error, :invalid_reset_token}`.
  """
  def reset_password(token, new_password) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "reset"}),
         {:ok, %User{} = user} <- Guardian.resource_from_claims(claims),
         {:ok, updated} <-
           user
           |> User.password_update_changeset(%{password: new_password})
           |> Repo.update() do
      Repo.delete_all(from(t in RefreshToken, where: t.user_id == ^updated.id))
      issue_tokens(updated)
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      _ -> {:error, :invalid_reset_token}
    end
  end

  def refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, claims} <- Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}),
         %RefreshToken{} = stored <- active_refresh_token(refresh_token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      Repo.delete!(stored)
      issue_tokens(user)
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  def refresh(_refresh_token), do: {:error, :invalid_refresh_token}

  def logout(refresh_token) when is_binary(refresh_token) do
    from(token in RefreshToken, where: token.token == ^refresh_token)
    |> Repo.delete_all()

    :ok
  end

  def logout(_refresh_token), do: :ok

  def verify_access_token(token) do
    with {:ok, claims} <- Guardian.decode_and_verify(token, %{"typ" => "access"}),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      {:ok, user, claims}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp with_tokens({:ok, user}), do: issue_tokens(user)
  defp with_tokens(error), do: error

  defp issue_tokens(user) do
    with {:ok, access_token, _access_claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "access", ttl: @access_ttl),
         {:ok, refresh_token, refresh_claims} <-
           Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: @refresh_ttl),
         {:ok, _stored_token} <- store_refresh_token(user, refresh_token, refresh_claims) do
      {:ok, %{user: user, access_token: access_token, refresh_token: refresh_token}}
    end
  end

  defp store_refresh_token(user, token, %{"exp" => expires_at}) do
    %RefreshToken{}
    |> RefreshToken.changeset(%{
      token: token,
      user_id: user.id,
      expires_at: DateTime.from_unix!(expires_at)
    })
    |> Repo.insert()
  end

  defp active_refresh_token(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    RefreshToken
    |> where([refresh_token], refresh_token.token == ^token and refresh_token.expires_at > ^now)
    |> Repo.one()
  end
end

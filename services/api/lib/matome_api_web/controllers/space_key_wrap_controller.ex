defmodule MatomeApiWeb.SpaceKeyWrapController do
  @moduledoc """
  ADR-0003 key-share endpoints — Core stores opaque wraps only.
  Admin permission ⟂ crypto access: uploading a wrap requires an existing
  member client; Core never holds Space-DEK plaintext.
  """
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def show_own(conn, %{"space_id" => space_id}) do
    case Content.get_own_space_key_wrap(conn.assigns.current_user, space_id) do
      nil -> not_found(conn)
      wrap -> json(conn, %{key_wrap: wrap_json(wrap)})
    end
  end

  def pending(conn, %{"space_id" => space_id}) do
    case Content.list_pending_key_shares(conn.assigns.current_user, space_id) do
      {:ok, members} ->
        json(conn, %{
          pending:
            Enum.map(members, fn m ->
              %{user_id: m.user_id, email: m.user.email, role: m.role}
            end)
        })

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
    end
  end

  def upsert(conn, %{"space_id" => space_id, "user_id" => user_id} = params) do
    recipient_id = parse_id(user_id)

    case Content.put_space_key_wrap(conn.assigns.current_user, space_id, recipient_id, params) do
      {:ok, wrap} ->
        conn |> put_status(:ok) |> json(%{key_wrap: wrap_json(wrap)})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      {:error, :not_a_member} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "not_a_member"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def delete(conn, %{"space_id" => space_id, "user_id" => user_id}) do
    recipient_id = parse_id(user_id)

    case Content.revoke_space_key_wrap(conn.assigns.current_user, space_id, recipient_id) do
      nil ->
        not_found(conn)

      {:ok, _wrap} ->
        send_resp(conn, :no_content, "")

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})
    end
  end

  defp wrap_json(wrap) do
    %{
      workspace_id: wrap.workspace_id,
      user_id: wrap.user_id,
      wrapper_blob: wrap.wrapper_blob,
      ephemeral_pubkey: wrap.ephemeral_pubkey,
      alg_id: wrap.alg_id,
      created_by_id: wrap.created_by_id,
      revoked_at: wrap.revoked_at,
      inserted_at: wrap.inserted_at,
      updated_at: wrap.updated_at
    }
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

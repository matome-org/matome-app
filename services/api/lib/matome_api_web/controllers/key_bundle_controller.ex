defmodule MatomeApiWeb.KeyBundleController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Auth

  # Every field here is an opaque, client-generated blob (see
  # .docs/internal/at-rest-key-flow.md Appendix A). This controller only
  # ever passes them straight through to `MatomeApi.Auth` — it never
  # inspects, decodes, or derives anything from their contents.
  @fields ~w(wrapped_dek_pw wrapped_dek_recovery salt_enc salt_rec salt_auth kdf_params)

  def show(conn, _params) do
    case Auth.get_key_bundle(conn.assigns.current_user) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      key_bundle -> json(conn, %{key_bundle: key_bundle_json(key_bundle)})
    end
  end

  def upsert(conn, params) do
    case Auth.upsert_key_bundle(conn.assigns.current_user, Map.take(params, @fields)) do
      {:ok, key_bundle} ->
        json(conn, %{key_bundle: key_bundle_json(key_bundle)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  defp key_bundle_json(key_bundle) do
    %{
      wrapped_dek_pw: key_bundle.wrapped_dek_pw,
      wrapped_dek_recovery: key_bundle.wrapped_dek_recovery,
      salt_enc: key_bundle.salt_enc,
      salt_rec: key_bundle.salt_rec,
      salt_auth: key_bundle.salt_auth,
      kdf_params: key_bundle.kdf_params,
      updated_at: key_bundle.updated_at
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

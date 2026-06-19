defmodule MatomeApiWeb.MatomeController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def index(conn, params) do
    json(conn, %{
      matomes: Enum.map(Content.list_matomes(conn.assigns.current_user, params), &matome_json/1)
    })
  end

  def search(conn, params), do: index(conn, params)

  def show(conn, %{"id" => id}) do
    case Content.get_matome(conn.assigns.current_user, id) do
      nil -> not_found(conn)
      matome -> json(conn, %{matome: matome_json(matome)})
    end
  end

  def create(conn, params) do
    case Content.create_matome(conn.assigns.current_user, params) do
      {:ok, matome} ->
        conn |> put_status(:created) |> json(%{matome: matome_json(matome)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Content.update_matome(conn.assigns.current_user, id, params) do
      nil ->
        not_found(conn)

      {:ok, matome} ->
        json(conn, %{matome: matome_json(matome)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.delete_matome(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, _matome} ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def attach_contact(conn, %{"matome_id" => matome_id, "contact_id" => contact_id} = params) do
    case Content.attach_contact(conn.assigns.current_user, matome_id, contact_id, params) do
      nil ->
        not_found(conn)

      {:ok, _join} ->
        case Content.get_matome(conn.assigns.current_user, matome_id) do
          nil -> not_found(conn)
          matome -> conn |> put_status(:created) |> json(%{matome: matome_json(matome)})
        end

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def detach_contact(conn, %{"matome_id" => matome_id, "contact_id" => contact_id}) do
    case Content.detach_contact(conn.assigns.current_user, matome_id, contact_id) do
      nil ->
        not_found(conn)

      {:ok, _join} ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  defp matome_json(matome) do
    %{
      id: matome.id,
      owner_id: matome.owner_id,
      workspace_id: matome.workspace_id,
      title: matome.title,
      happened_at: matome.happened_at,
      description: matome.description,
      aggregated_summary: matome.aggregated_summary,
      contacts: Enum.map(matome.matome_contacts, &contact_link_json/1),
      inserted_at: matome.inserted_at,
      updated_at: matome.updated_at
    }
  end

  defp contact_link_json(matome_contact) do
    %{
      contact_id: matome_contact.contact_id,
      role: matome_contact.role
    }
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

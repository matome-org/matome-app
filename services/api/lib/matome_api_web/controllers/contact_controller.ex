defmodule MatomeApiWeb.ContactController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def index(conn, params) do
    json(conn, %{
      contacts: Enum.map(Content.list_contacts(conn.assigns.current_user, params), &contact_json/1)
    })
  end

  def search(conn, params), do: index(conn, params)

  def show(conn, %{"id" => id}) do
    case Content.get_contact(conn.assigns.current_user, id) do
      nil -> not_found(conn)
      contact -> json(conn, %{contact: contact_json(contact)})
    end
  end

  def create(conn, params) do
    case Content.create_contact(conn.assigns.current_user, params) do
      {:ok, contact} ->
        conn |> put_status(:created) |> json(%{contact: contact_json(contact)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Content.update_contact(conn.assigns.current_user, id, params) do
      nil ->
        not_found(conn)

      {:ok, contact} ->
        json(conn, %{contact: contact_json(contact)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.delete_contact(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, _contact} ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  defp contact_json(contact) do
    %{
      id: contact.id,
      owner_id: contact.owner_id,
      display_name: contact.display_name,
      email: contact.email,
      phone: contact.phone,
      company: contact.company,
      title: contact.title,
      metadata: contact.metadata,
      linked_user_id: contact.linked_user_id,
      inserted_at: contact.inserted_at,
      updated_at: contact.updated_at
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

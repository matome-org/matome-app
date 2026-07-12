defmodule MatomeApiWeb.WorkspaceController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def index(conn, params) do
    json(conn, %{
      workspaces:
        Enum.map(Content.list_workspaces(conn.assigns.current_user, params), &workspace_json/1)
    })
  end

  def search(conn, params), do: index(conn, params)

  def show(conn, %{"id" => id}) do
    case Content.get_workspace(conn.assigns.current_user, id) do
      nil -> not_found(conn)
      workspace -> json(conn, %{workspace: workspace_json(workspace)})
    end
  end

  def create(conn, params) do
    case Content.create_workspace(conn.assigns.current_user, params) do
      {:ok, workspace} ->
        conn |> put_status(:created) |> json(%{workspace: workspace_json(workspace)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Content.update_workspace(conn.assigns.current_user, id, params) do
      nil ->
        not_found(conn)

      {:ok, workspace} ->
        json(conn, %{workspace: workspace_json(workspace)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Content.delete_workspace(conn.assigns.current_user, id) do
      nil ->
        not_found(conn)

      {:ok, _workspace} ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  defp workspace_json(workspace) do
    %{
      id: workspace.id,
      owner_id: workspace.owner_id,
      name: workspace.name,
      description: workspace.description,
      is_local: workspace.is_local,
      space_type: workspace.space_type,
      quota_bytes: workspace.quota_bytes,
      used_bytes: workspace.used_bytes,
      expires_at: workspace.expires_at,
      status: workspace.status,
      inserted_at: workspace.inserted_at,
      updated_at: workspace.updated_at
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

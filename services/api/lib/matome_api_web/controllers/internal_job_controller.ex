defmodule MatomeApiWeb.InternalJobController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def result(conn, %{"id" => route_job_id, "job_id" => body_job_id} = params) do
    with true <- route_job_id == body_job_id,
         {:ok, item_id, file_blob_id} <- parse_item_job_id(route_job_id),
         true <- Content.persisted_ai_dispatch?(item_id, file_blob_id) do
      case Content.update_file_item_result(item_id, file_blob_id, params) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "not_found"})

        {:ok, _item} ->
          send_resp(conn, :no_content, "")

        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
      end
    else
      _ -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  def result(conn, _params) do
    conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end

  defp parse_item_job_id("item:" <> rest) do
    case String.split(rest, ":file_blob:", parts: 2) do
      [item_id, file_blob_id] ->
        with {item_id, ""} <- Integer.parse(item_id),
             {file_blob_id, ""} <- Integer.parse(file_blob_id) do
          {:ok, item_id, file_blob_id}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_item_job_id(_), do: :error

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

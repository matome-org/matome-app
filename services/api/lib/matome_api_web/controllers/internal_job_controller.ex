defmodule MatomeApiWeb.InternalJobController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def result(conn, %{"id" => route_job_id} = params) do
    case Content.apply_processing_callback(route_job_id, Map.delete(params, "id")) do
      {:ok, _applied_duplicate_or_stale} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, _invalid} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid_callback"})
    end
  end

  def result(conn, _params) do
    conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end
end

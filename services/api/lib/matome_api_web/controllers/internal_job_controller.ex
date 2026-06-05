defmodule MatomeApiWeb.InternalJobController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def result(conn, %{"id" => job_id} = params) do
    case Content.apply_ai_result(job_id, params) do
      {:ok, _recording} ->
        send_resp(conn, :no_content, "")

      :not_found ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, :recording_mismatch} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "recording_mismatch"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors_on(changeset)})
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

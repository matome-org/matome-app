defmodule MatomeApiWeb.UploadController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Content

  def request(conn, %{"item_id" => item_id} = params) do
    respond(conn, Content.request_item_upload(conn.assigns.current_user, item_id, params))
  end

  def inspect(conn, %{"upload_id" => upload_id}) do
    respond(conn, Content.inspect_item_upload(conn.assigns.current_user, upload_id))
  end

  def presign_part(
        conn,
        %{
          "upload_id" => upload_id,
          "part_number" => part_number
        } = params
      ) do
    case Content.presign_item_upload_part(
           conn.assigns.current_user,
           upload_id,
           part_number,
           params
         ) do
      nil -> not_found(conn)
      {:ok, part} -> json(conn, %{contract_version: "1", part: part})
      {:error, reason} -> error(conn, reason)
    end
  end

  def complete(conn, %{"upload_id" => upload_id} = params) do
    respond(conn, Content.complete_item_upload(conn.assigns.current_user, upload_id, params))
  end

  def abort(conn, %{"upload_id" => upload_id} = params) do
    respond(conn, Content.abort_item_upload(conn.assigns.current_user, upload_id, params))
  end

  defp respond(conn, nil), do: not_found(conn)
  defp respond(conn, {:ok, upload}), do: json(conn, %{contract_version: "1", upload: upload})
  defp respond(conn, {:error, reason}), do: error(conn, reason)

  defp error(conn, :stale_upload_generation),
    do: conn |> put_status(:conflict) |> json(%{error: "stale_upload_generation"})

  defp error(conn, :upload_expired),
    do: conn |> put_status(:gone) |> json(%{error: "upload_expired"})

  defp error(conn, reason) when is_atom(reason),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: Atom.to_string(reason)})

  defp error(conn, _reason),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: "upload_failed"})

  defp not_found(conn), do: conn |> put_status(:not_found) |> json(%{error: "not_found"})
end

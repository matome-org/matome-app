defmodule MatomeApiWeb.DeviceQueueSnapshotController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Auth.DeviceQueueReports

  def create(conn, params) do
    case DeviceQueueReports.report(
           conn.assigns.current_user,
           conn.assigns.current_device_id,
           params
         ) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, :device_not_registered} -> validation_error(conn, "device_not_registered")
      {:error, _reason} -> validation_error(conn, "invalid_queue_snapshot")
    end
  end

  defp validation_error(conn, error) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: error})
  end
end

defmodule MatomeApiWeb.ProductEventController do
  use MatomeApiWeb, :controller

  alias MatomeApi.Events

  def create(conn, %{"opted_in" => true, "catalog_key" => key, "payload" => payload}) do
    user = conn.assigns.current_user

    attrs = %{
      actor_id: user.id,
      owner_id: user.id,
      device_id: conn.assigns.current_device_id,
      source_type: "flutter",
      source_id: "authenticated-client"
    }

    case Events.write_product(key, payload, attrs) do
      {:ok, :disabled} -> conn |> put_status(:accepted) |> json(%{status: "disabled"})
      {:ok, _event} -> conn |> put_status(:created) |> json(%{status: "recorded"})
      {:error, :event_not_allowed} -> validation_error(conn, "event_not_allowed")
      {:error, _reason} -> validation_error(conn, "invalid_event")
    end
  end

  def create(conn, %{"opted_in" => false}), do: send_resp(conn, :no_content, "")
  def create(conn, _params), do: validation_error(conn, "invalid_event")

  defp validation_error(conn, error) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: error})
  end
end

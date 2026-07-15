defmodule MatomeApiWeb.SystemConfigController do
  use MatomeApiWeb, :controller

  alias MatomeApi.SystemConfig

  def show(conn, _params) do
    status = SystemConfig.status()

    json(conn, %{
      contract_version: "1",
      config: status.config,
      effective: %{queue: status.queue}
    })
  end

  def application(
        conn,
        %{
          "contract_version" => "1",
          "applied_revision" => revision,
          "rejected_keys" => rejected_keys
        } = params
      )
      when map_size(params) == 3 and is_integer(revision) and is_list(rejected_keys) do
    if revision >= 0 and revision <= SystemConfig.current_revision() and
         valid_rejected_keys?(rejected_keys) do
      send_resp(conn, :no_content, "")
    else
      invalid_report(conn)
    end
  end

  def application(conn, _params), do: invalid_report(conn)

  defp valid_rejected_keys?(keys) do
    length(keys) <= 32 and
      Enum.all?(keys, fn key ->
        is_binary(key) and byte_size(key) in 1..128 and
          Regex.match?(~r/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/, key)
      end)
  end

  defp invalid_report(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalid_application_report"})
  end
end

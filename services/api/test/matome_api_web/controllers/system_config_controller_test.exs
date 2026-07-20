defmodule MatomeApiWeb.SystemConfigControllerTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.SystemConfig

  @password "correct horse battery staple"

  test "fetch and application report require auth and expose only non-secret policy", %{
    conn: conn
  } do
    assert conn |> get(~p"/api/system-config") |> json_response(401)

    owner_conn = register_conn(conn)
    response = owner_conn |> get(~p"/api/system-config") |> json_response(200)

    assert response["contract_version"] == "1"
    assert response["config"]["revision"] == SystemConfig.current_revision()
    assert response["config"]["desired"]["queue"]["paused"] == false
    assert is_boolean(response["effective"]["queue"]["mismatch"])
    assert is_boolean(response["effective"]["queue"]["restart_required"])

    encoded = Jason.encode!(response)
    refute encoded =~ "token"
    refute encoded =~ "secret"
    refute encoded =~ "endpoint"
    refute encoded =~ "url"

    revision = response["config"]["revision"]

    owner_conn
    |> post(~p"/api/system-config/application", %{
      contract_version: "1",
      applied_revision: revision,
      rejected_keys: []
    })
    |> response(204)

    owner_conn
    |> post(~p"/api/system-config/application", %{
      contract_version: "1",
      applied_revision: revision + 1,
      rejected_keys: []
    })
    |> json_response(422)
    |> then(&assert &1["error"] == "invalid_application_report")
  end

  defp register_conn(conn) do
    email = "config-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, %{access_token: token}} =
             Auth.register_user(%{email: email, password: @password})

    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end

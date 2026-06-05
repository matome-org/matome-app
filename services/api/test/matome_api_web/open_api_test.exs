defmodule MatomeApiWeb.OpenApiTest do
  use MatomeApiWeb.ConnCase, async: true

  test "GET /openapi serves a valid minimal spec", %{conn: conn} do
    conn = get(conn, ~p"/openapi")
    body = json_response(conn, 200)

    assert body["openapi"] =~ "3."
    assert body["info"]["title"] == "Matome Core API"
    assert Map.has_key?(body["paths"], "/health")
    assert Map.has_key?(body["paths"], "/api/auth/register")
    assert Map.has_key?(body["paths"], "/api/auth/login")
    assert Map.has_key?(body["paths"], "/api/auth/refresh")
    assert Map.has_key?(body["paths"], "/api/auth/logout")
    assert Map.has_key?(body["paths"], "/api/auth/me")
    assert Map.has_key?(body["paths"], "/api/spaces")
    assert Map.has_key?(body["paths"], "/api/spaces/search")
    assert Map.has_key?(body["paths"], "/api/spaces/{id}")
    assert Map.has_key?(body["paths"], "/api/recordings")
    assert Map.has_key?(body["paths"], "/api/recordings/search")
    assert Map.has_key?(body["paths"], "/api/recordings/{id}")
    assert Map.has_key?(body["paths"], "/api/recordings/{id}/download-url")
    assert Map.has_key?(body["paths"], "/api/recordings/{id}/process")
  end
end

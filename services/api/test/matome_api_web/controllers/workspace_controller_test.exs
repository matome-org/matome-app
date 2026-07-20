defmodule MatomeApiWeb.WorkspaceControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  @password "correct horse battery staple"

  test "authenticated users CRUD only their own spaces", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    create_conn = post(owner_conn, ~p"/api/spaces", %{name: "Research", description: "Owned"})
    workspace = json_response(create_conn, 201)["workspace"]

    assert get(owner_conn, ~p"/api/spaces/#{workspace["id"]}") |> json_response(200)
    assert get(other_conn, ~p"/api/spaces/#{workspace["id"]}") |> json_response(404)

    list = get(other_conn, ~p"/api/spaces") |> json_response(200)
    assert list["workspaces"] == []

    updated =
      put(owner_conn, ~p"/api/spaces/#{workspace["id"]}", %{description: "Updated"})
      |> json_response(200)

    assert updated["workspace"]["description"] == "Updated"

    search = get(owner_conn, ~p"/api/spaces/search?q=Research") |> json_response(200)
    assert length(search["workspaces"]) == 1

    assert delete(other_conn, ~p"/api/spaces/#{workspace["id"]}") |> json_response(404)
    assert delete(owner_conn, ~p"/api/spaces/#{workspace["id"]}") |> response(204) == ""
  end

  defp register_conn(conn) do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    register_conn = post(conn, ~p"/api/auth/register", %{email: email, password: @password})
    %{"access_token" => access_token, "user" => user} = json_response(register_conn, 201)

    %{
      conn: build_conn() |> put_req_header("authorization", "Bearer #{access_token}"),
      user: user
    }
  end
end

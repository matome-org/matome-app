defmodule MatomeApiWeb.MatomeControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  @password "correct horse battery staple"

  test "authenticated users CRUD only their own matomes", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "Kickoff", description: "Owned"})
      |> json_response(201)
      |> get_in(["matome"])

    assert created["title"] == "Kickoff"
    assert created["workspace_id"] == nil
    assert created["contacts"] == []

    assert get(owner_conn, ~p"/api/matomes/#{created["id"]}") |> json_response(200)
    assert get(other_conn, ~p"/api/matomes/#{created["id"]}") |> json_response(404)

    list = get(other_conn, ~p"/api/matomes") |> json_response(200)
    assert list["matomes"] == []

    updated =
      put(owner_conn, ~p"/api/matomes/#{created["id"]}", %{description: "Edited"})
      |> json_response(200)

    assert updated["matome"]["description"] == "Edited"

    assert delete(other_conn, ~p"/api/matomes/#{created["id"]}") |> json_response(404)
    assert delete(owner_conn, ~p"/api/matomes/#{created["id"]}") |> response(204) == ""
  end

  test "matome workspace assignment is owner scoped", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    other_workspace =
      post(other_conn, ~p"/api/spaces", %{name: "Other"})
      |> json_response(201)
      |> get_in(["workspace"])

    invalid =
      post(owner_conn, ~p"/api/matomes", %{title: "Secret", workspace_id: other_workspace["id"]})

    assert %{"errors" => %{"workspace_id" => ["is invalid"]}} = json_response(invalid, 422)
  end

  test "matome search is owner scoped", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    post(owner_conn, ~p"/api/matomes", %{title: "needle meeting"})
    post(other_conn, ~p"/api/matomes", %{title: "needle meeting"})

    search = get(owner_conn, ~p"/api/matomes/search?q=needle") |> json_response(200)
    assert length(search["matomes"]) == 1
  end

  test "attach and detach a contact to a matome", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    matome =
      post(owner_conn, ~p"/api/matomes", %{title: "Standup"})
      |> json_response(201)
      |> get_in(["matome"])

    contact =
      post(owner_conn, ~p"/api/contacts", %{display_name: "Alice"})
      |> json_response(201)
      |> get_in(["contact"])

    attached =
      post(owner_conn, ~p"/api/matomes/#{matome["id"]}/contacts", %{
        contact_id: contact["id"],
        role: "speaker"
      })
      |> json_response(201)
      |> get_in(["matome"])

    assert attached["contacts"] == [%{"contact_id" => contact["id"], "role" => "speaker"}]

    # other owner cannot attach to this matome
    assert post(other_conn, ~p"/api/matomes/#{matome["id"]}/contacts", %{
             contact_id: contact["id"]
           })
           |> json_response(404)

    assert delete(owner_conn, ~p"/api/matomes/#{matome["id"]}/contacts/#{contact["id"]}")
           |> response(204) == ""

    refetched = get(owner_conn, ~p"/api/matomes/#{matome["id"]}") |> json_response(200)
    assert refetched["matome"]["contacts"] == []
  end

  test "recordings can be assigned to an owned matome but not another owner's", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    matome =
      post(owner_conn, ~p"/api/matomes", %{title: "Mine"})
      |> json_response(201)
      |> get_in(["matome"])

    other_matome =
      post(other_conn, ~p"/api/matomes", %{title: "Theirs"})
      |> json_response(201)
      |> get_in(["matome"])

    ok =
      post(owner_conn, ~p"/api/recordings", %{title: "Item", matome_id: matome["id"]})
      |> json_response(201)
      |> get_in(["recording"])

    assert ok["matome_id"] == matome["id"]

    invalid =
      post(owner_conn, ~p"/api/recordings", %{title: "Bad", matome_id: other_matome["id"]})

    assert %{"errors" => %{"matome_id" => ["is invalid"]}} = json_response(invalid, 422)
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

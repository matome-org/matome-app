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

  test "client identity makes create replay-safe and conflicts without duplicating", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    params = %{client_id: "matome-local-api-1", title: "Offline parent", description: "Original"}

    first = post(owner_conn, ~p"/api/matomes", params) |> json_response(201)
    replay = post(owner_conn, ~p"/api/matomes", params) |> json_response(201)

    assert first["matome"]["id"] == replay["matome"]["id"]
    assert first["matome"]["client_id"] == "matome-local-api-1"

    assert post(owner_conn, ~p"/api/matomes", %{params | description: "Changed"})
           |> json_response(409) == %{"error" => "client_id_conflict"}

    assert MatomeApi.Repo.aggregate(MatomeApi.Content.Matome, :count, :id) == 1
  end

  test "owner renames a matome and updates happened_at", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "Draft"})
      |> json_response(201)
      |> get_in(["matome"])

    updated =
      patch(owner_conn, ~p"/api/matomes/#{created["id"]}", %{
        title: "  Renamed  ",
        happened_at: "2026-01-15T10:30:00Z"
      })
      |> json_response(200)
      |> get_in(["matome"])

    assert updated["title"] == "Renamed"
    assert updated["happened_at"] == "2026-01-15T10:30:00Z"

    refetched =
      get(owner_conn, ~p"/api/matomes/#{created["id"]}")
      |> json_response(200)
      |> get_in(["matome"])

    assert refetched["title"] == "Renamed"
    assert refetched["happened_at"] == "2026-01-15T10:30:00Z"
  end

  test "update rejects an empty title and garbage happened_at", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "Keep me"})
      |> json_response(201)
      |> get_in(["matome"])

    blank = patch(owner_conn, ~p"/api/matomes/#{created["id"]}", %{title: "   "})
    assert %{"errors" => %{"title" => [_ | _]}} = json_response(blank, 422)

    far_future =
      patch(owner_conn, ~p"/api/matomes/#{created["id"]}", %{happened_at: "9999-01-01T00:00:00Z"})

    assert %{"errors" => %{"happened_at" => [_ | _]}} = json_response(far_future, 422)

    far_past =
      patch(owner_conn, ~p"/api/matomes/#{created["id"]}", %{happened_at: "1800-01-01T00:00:00Z"})

    assert %{"errors" => %{"happened_at" => [_ | _]}} = json_response(far_past, 422)

    # title is preserved after rejected updates
    refetched =
      get(owner_conn, ~p"/api/matomes/#{created["id"]}")
      |> json_response(200)
      |> get_in(["matome"])

    assert refetched["title"] == "Keep me"
  end

  test "an out-of-scope actor cannot update another owner's matome", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "Private"})
      |> json_response(201)
      |> get_in(["matome"])

    # cross-owner PATCH must be blocked, not silently applied
    assert patch(other_conn, ~p"/api/matomes/#{created["id"]}", %{title: "Hijacked"})
           |> json_response(404)

    # the owner's title is untouched
    refetched =
      get(owner_conn, ~p"/api/matomes/#{created["id"]}")
      |> json_response(200)
      |> get_in(["matome"])

    assert refetched["title"] == "Private"
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

  test "archive sets archived_at and the matome drops out of the list", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "To archive"})
      |> json_response(201)
      |> get_in(["matome"])

    # before archiving, it is in the list
    listed = get(owner_conn, ~p"/api/matomes") |> json_response(200)
    assert Enum.any?(listed["matomes"], &(&1["id"] == created["id"]))

    archived =
      post(owner_conn, ~p"/api/matomes/#{created["id"]}/archive")
      |> json_response(200)
      |> get_in(["matome"])

    assert archived["archived_at"] != nil

    # after archiving, it leaves the default list and the show endpoint
    after_list = get(owner_conn, ~p"/api/matomes") |> json_response(200)
    refute Enum.any?(after_list["matomes"], &(&1["id"] == created["id"]))
    assert get(owner_conn, ~p"/api/matomes/#{created["id"]}") |> json_response(404)
  end

  test "restore clears archived_at and the matome returns to the list", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "Round trip"})
      |> json_response(201)
      |> get_in(["matome"])

    post(owner_conn, ~p"/api/matomes/#{created["id"]}/archive") |> json_response(200)

    restored =
      post(owner_conn, ~p"/api/matomes/#{created["id"]}/restore")
      |> json_response(200)
      |> get_in(["matome"])

    assert restored["archived_at"] == nil

    after_list = get(owner_conn, ~p"/api/matomes") |> json_response(200)
    assert Enum.any?(after_list["matomes"], &(&1["id"] == created["id"]))
    assert get(owner_conn, ~p"/api/matomes/#{created["id"]}") |> json_response(200)
  end

  test "an out-of-scope actor cannot archive or restore another owner's matome",
       %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "Private"})
      |> json_response(201)
      |> get_in(["matome"])

    # cross-owner archive must be blocked, not silently applied
    assert post(other_conn, ~p"/api/matomes/#{created["id"]}/archive")
           |> json_response(404)

    # the owner's matome is untouched (still visible, not archived)
    refetched =
      get(owner_conn, ~p"/api/matomes/#{created["id"]}")
      |> json_response(200)
      |> get_in(["matome"])

    assert refetched["archived_at"] == nil

    # archive it as the owner, then a cross-owner restore is also blocked
    post(owner_conn, ~p"/api/matomes/#{created["id"]}/archive") |> json_response(200)

    assert post(other_conn, ~p"/api/matomes/#{created["id"]}/restore")
           |> json_response(404)
  end

  test "archived matomes are excluded from search", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    created =
      post(owner_conn, ~p"/api/matomes", %{title: "needle archived"})
      |> json_response(201)
      |> get_in(["matome"])

    post(owner_conn, ~p"/api/matomes/#{created["id"]}/archive") |> json_response(200)

    search = get(owner_conn, ~p"/api/matomes/search?q=needle") |> json_response(200)
    assert search["matomes"] == []
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

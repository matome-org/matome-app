defmodule MatomeApiWeb.ContactControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  @password "correct horse battery staple"

  test "authenticated users CRUD only their own contacts", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    created =
      post(owner_conn, ~p"/api/contacts", %{
        display_name: "Alice",
        metadata: %{"company" => "Acme"}
      })
      |> json_response(201)
      |> get_in(["contact"])

    assert created["display_name"] == "Alice"
    assert created["metadata"] == %{"company" => "Acme"}
    assert created["linked_user_id"] == nil

    assert get(owner_conn, ~p"/api/contacts/#{created["id"]}") |> json_response(200)
    assert get(other_conn, ~p"/api/contacts/#{created["id"]}") |> json_response(404)

    list = get(other_conn, ~p"/api/contacts") |> json_response(200)
    assert list["contacts"] == []

    updated =
      put(owner_conn, ~p"/api/contacts/#{created["id"]}", %{display_name: "Alice Cooper"})
      |> json_response(200)

    assert updated["contact"]["display_name"] == "Alice Cooper"

    assert delete(other_conn, ~p"/api/contacts/#{created["id"]}") |> json_response(404)
    assert delete(owner_conn, ~p"/api/contacts/#{created["id"]}") |> response(204) == ""
  end

  test "contact validation requires a display name", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    invalid = post(owner_conn, ~p"/api/contacts", %{metadata: %{}})
    assert %{"errors" => %{"display_name" => ["can't be blank"]}} = json_response(invalid, 422)
  end

  test "structured fields round-trip and are owner scoped over HTTP", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    created =
      post(owner_conn, ~p"/api/contacts", %{
        display_name: "Alice",
        email: "Alice@Example.COM",
        phone: "+1 (555) 123-4567",
        company: "Acme",
        title: "CEO"
      })
      |> json_response(201)
      |> get_in(["contact"])

    assert created["email"] == "alice@example.com"
    assert created["phone"] == "+15551234567"
    assert created["company"] == "Acme"
    assert created["title"] == "CEO"

    fetched = get(owner_conn, ~p"/api/contacts/#{created["id"]}") |> json_response(200)
    assert fetched["contact"]["email"] == "alice@example.com"

    # owner B can neither read nor write owner A's structured fields
    assert get(other_conn, ~p"/api/contacts/#{created["id"]}") |> json_response(404)

    assert put(other_conn, ~p"/api/contacts/#{created["id"]}", %{email: "evil@example.com"})
           |> json_response(404)
  end

  test "contact write rejects malformed email and phone", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)

    bad_email =
      post(owner_conn, ~p"/api/contacts", %{display_name: "Bad", email: "not-an-email"})

    assert %{"errors" => %{"email" => ["is not a valid email"]}} =
             json_response(bad_email, 422)

    bad_phone = post(owner_conn, ~p"/api/contacts", %{display_name: "Bad", phone: "abc-123"})

    assert %{"errors" => %{"phone" => ["is not a valid phone number"]}} =
             json_response(bad_phone, 422)
  end

  test "contact search is owner scoped", %{conn: conn} do
    %{conn: owner_conn} = register_conn(conn)
    %{conn: other_conn} = register_conn(build_conn())

    post(owner_conn, ~p"/api/contacts", %{display_name: "Needle Person"})
    post(other_conn, ~p"/api/contacts", %{display_name: "Needle Person"})

    search = get(owner_conn, ~p"/api/contacts/search?q=Needle") |> json_response(200)
    assert length(search["contacts"]) == 1
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

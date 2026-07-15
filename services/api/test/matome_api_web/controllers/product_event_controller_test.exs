defmodule MatomeApiWeb.ProductEventControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.Auth.RefreshToken
  alias MatomeApi.Events.{Event, EventCatalog}
  alias MatomeApi.Repo

  @password "correct horse battery staple"
  @key "product.capture_completed.v1"

  test "requires an authenticated user", %{conn: conn} do
    assert conn
           |> post("/api/events", %{catalog_key: @key, opted_in: true, payload: %{}})
           |> json_response(401) == %{"error" => "unauthorized"}
  end

  test "accepts only enabled optional product keys and derives identity", %{conn: conn} do
    enable!(@key)
    %{conn: authed, user: user, device_id: device_id} = auth_conn(conn)

    response =
      post(authed, "/api/events", %{
        catalog_key: @key,
        opted_in: true,
        actor_id: -1,
        owner_id: -1,
        device_id: -1,
        payload: %{
          input_kind: "audio",
          duration_bucket: "short",
          size_bucket: "small",
          platform: "linux",
          result: "ok"
        }
      })
      |> json_response(201)

    assert response == %{"status" => "recorded"}

    assert %Event{
             actor_id: actor_id,
             owner_id: owner_id,
             device_id: ^device_id,
             source_type: "flutter"
           } = Repo.one!(from e in Event, where: e.event_key == @key)

    assert actor_id == user.id
    assert owner_id == user.id
  end

  test "rejects spoofed security, operational, and unknown keys", %{conn: conn} do
    %{conn: authed} = auth_conn(conn)

    for key <- [
          "security.admin.login.v1",
          "operational.upload_completed.v1",
          "product.not_cataloged.v1"
        ] do
      assert authed
             |> post("/api/events", %{catalog_key: key, opted_in: true, payload: %{}})
             |> json_response(422) == %{"error" => "event_not_allowed"}
    end

    refute Repo.exists?(from e in Event, where: e.event_key == "security.admin.login.v1")
  end

  test "consent false and disabled catalog both insert no rows", %{conn: conn} do
    %{conn: authed} = auth_conn(conn)

    assert authed
           |> post("/api/events", %{catalog_key: @key, opted_in: false, payload: %{}})
           |> response(204) == ""

    assert authed
           |> post("/api/events", %{catalog_key: @key, opted_in: true, payload: %{}})
           |> json_response(202) == %{"status" => "disabled"}

    refute Repo.exists?(from e in Event, where: e.event_key == @key)
  end

  test "payload remains bounded by the catalog schema", %{conn: conn} do
    enable!(@key)
    %{conn: authed} = auth_conn(conn)

    assert authed
           |> post("/api/events", %{
             catalog_key: @key,
             opted_in: true,
             payload: %{input_kind: String.duplicate("x", 513)}
           })
           |> json_response(422) == %{"error" => "invalid_event"}

    refute Repo.exists?(from e in Event, where: e.event_key == @key)
  end

  defp enable!(key) do
    key
    |> then(&Repo.get!(EventCatalog, &1))
    |> EventCatalog.changeset(%{enabled: true})
    |> Repo.update!()
  end

  defp auth_conn(conn) do
    {:ok, auth} =
      Auth.register_user(
        %{
          "email" => "events-#{System.unique_integer([:positive])}@example.com",
          "password" => @password
        },
        %{
          device: %{
            "id" => Ecto.UUID.generate(),
            "platform" => "linux",
            "form_factor" => "desktop",
            "device_class" => "desktop",
            "display_name" => "Test workstation"
          }
        }
      )

    token = Repo.get_by!(RefreshToken, token: auth.refresh_token)

    %{
      conn: put_req_header(conn, "authorization", "Bearer #{auth.access_token}"),
      user: auth.user,
      device_id: token.device_id
    }
  end
end

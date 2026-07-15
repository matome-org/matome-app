defmodule MatomeApiWeb.AdminEventsLiveTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Events

  defp admin_session(conn) do
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: ["events-admin@example.com"])
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)

    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_email" => "events-admin@example.com",
      "admin_authenticated_at" => now,
      "admin_otp_verified_at" => now
    })
  end

  test "timeline is protected and exposes every indexed filter", %{conn: conn} do
    assert conn |> get("/admin/events") |> redirected_to() == "/admin/login"

    html =
      conn
      |> admin_session()
      |> get("/admin/events")
      |> html_response(200)

    assert html =~ "Events"

    for name <-
          ~w(event_class event_key actor owner_id subject_type subject_id device_id run_id severity since until) do
      assert html =~ ~s(name="#{name}")
    end

    assert html =~ "/admin/events/security"
    assert html =~ "/admin/event-catalog"
  end

  test "security saved view is locked to security rows", %{conn: conn} do
    Events.write_security!("security.admin.logout.v1", %{actor_email: "events-admin@example.com"})

    assert {:ok, _event} =
             Events.write_optional("operational.upload_completed.v1", %{
               details: %{mode: "single", result: "ok"}
             })

    html =
      conn
      |> admin_session()
      |> get("/admin/events/security")
      |> html_response(200)

    assert html =~ "Security saved view"
    assert html =~ "locked"
    assert html =~ "security.admin.logout.v1"
    refute html =~ "operational.upload_completed.v1"
  end

  test "a high-volume timeline renders one bounded page", %{conn: conn} do
    for index <- 1..125 do
      Events.write_security!("security.admin.logout.v1", %{
        correlation_id: "bounded-#{index}",
        occurred_at: ~U[2026-07-15 12:00:00Z]
      })
    end

    html =
      conn
      |> admin_session()
      |> get("/admin/events")
      |> html_response(200)

    assert length(Regex.scan(~r/matome-table__row/, html)) == 50
    assert html =~ "Next page"
  end
end

defmodule MatomeApiWeb.AdminEventCatalogLiveTest do
  use MatomeApiWeb.ConnCase, async: false

  import Ecto.Query

  alias MatomeApi.Events.{Event, EventCatalog}
  alias MatomeApi.Repo
  alias MatomeApiWeb.AdminLive.EventCatalog, as: EventCatalogLive

  @admin "catalog-admin@example.com"

  defp allowlist! do
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: [@admin])
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)
  end

  defp admin_session(conn) do
    allowlist!()
    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_email" => @admin,
      "admin_authenticated_at" => now,
      "admin_otp_verified_at" => now
    })
  end

  defp socket(overrides \\ %{}) do
    allowlist!()

    assigns =
      Map.merge(
        %{
          __changed__: %{},
          flash: %{},
          live_action: :index,
          current_admin: %{email: @admin},
          otp_verified_at: System.os_time(:second),
          client_ip: "192.0.2.44",
          catalogs: Repo.all(from c in EventCatalog, order_by: [asc: c.key]),
          catalog_class: nil
        },
        overrides
      )

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  test "catalog is protected and renders controls only for optional rows", %{conn: conn} do
    assert conn |> get("/admin/event-catalog") |> redirected_to() == "/admin/login"

    html =
      conn
      |> admin_session()
      |> get("/admin/event-catalog")
      |> html_response(200)

    assert html =~ "Event catalog"
    assert html =~ "security.admin.login.v1"
    assert html =~ "operational.upload_completed.v1"
    assert html =~ "Locked"
    assert html =~ ~s(phx-submit="update_catalog")
    refute html =~ ~s(phx-value-key="security.admin.login.v1")
  end

  test "optional policy mutation requires fresh OTP and audits itself" do
    {:noreply, result} =
      EventCatalogLive.handle_event(
        "update_catalog",
        %{
          "key" => "operational.upload_completed.v1",
          "enabled" => "false",
          "retention_days" => "120"
        },
        socket()
      )

    assert Repo.get!(EventCatalog, "operational.upload_completed.v1").enabled == false
    assert Repo.get!(EventCatalog, "operational.upload_completed.v1").retention_days == 120
    assert result.assigns.flash["info"] =~ "updated"

    event =
      Repo.one!(
        from e in Event,
          where: e.event_key == "security.event_catalog.changed.v2",
          order_by: [desc: e.id],
          limit: 1
      )

    assert event.actor_email == @admin
    assert event.subject_id == "operational.upload_completed.v1"
    assert event.remote_ip == "192.0.2.44"
  end

  test "stale OTP redirects before optional policy changes" do
    before = Repo.get!(EventCatalog, "operational.upload_completed.v1")

    {:noreply, result} =
      EventCatalogLive.handle_event(
        "update_catalog",
        %{
          "key" => before.key,
          "enabled" => "false",
          "retention_days" => "120"
        },
        socket(%{otp_verified_at: System.os_time(:second) - 3600})
      )

    assert {:redirect, %{to: to}} = result.redirected
    assert to =~ "/admin/otp"
    assert Repo.get!(EventCatalog, before.key).enabled == before.enabled
  end

  test "allowlist removal after mount blocks optional policy changes" do
    before = Repo.get!(EventCatalog, "operational.upload_completed.v1")
    mounted = socket()
    current = Application.get_env(:matome_api, :admin_panel, [])
    Application.put_env(:matome_api, :admin_panel, Keyword.put(current, :email_allowlist, []))

    {:noreply, result} =
      EventCatalogLive.handle_event(
        "update_catalog",
        %{
          "key" => before.key,
          "enabled" => "false",
          "retention_days" => "120"
        },
        mounted
      )

    assert {:redirect, %{to: "/admin/login"}} = result.redirected
    assert Repo.get!(EventCatalog, before.key).enabled == before.enabled
  end
end

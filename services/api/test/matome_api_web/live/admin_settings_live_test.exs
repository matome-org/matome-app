defmodule MatomeApiWeb.AdminSettingsLiveTest do
  use MatomeApiWeb.ConnCase, async: false

  import Ecto.Query

  alias MatomeApi.Events.Event
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig
  alias MatomeApiWeb.AdminLive.Settings

  @admin "settings-admin@example.com"

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

    %Phoenix.LiveView.Socket{
      assigns:
        Map.merge(
          %{
            __changed__: %{},
            flash: %{},
            live_action: :index,
            current_admin: %{email: @admin},
            otp_verified_at: System.os_time(:second),
            client_ip: "192.0.2.44",
            status: SystemConfig.status()
          },
          overrides
        )
    }
  end

  test "settings are admin-protected and render desired/effective state", %{conn: conn} do
    assert conn |> get("/admin/settings") |> redirected_to() == "/admin/login"

    html =
      conn
      |> admin_session()
      |> get("/admin/settings")
      |> html_response(200)

    assert html =~ "System settings"
    assert html =~ "Desired revision"
    assert html =~ "Effective Oban state"
    assert html =~ ~s(phx-submit="update_policy")
    assert html =~ ~s(phx-submit="toggle_queue")
    refute html =~ "AI_ENGINE_TOKEN"
    refute html =~ "dev-ai-token"
    refute html =~ "http://"
  end

  test "pause requires fresh OTP and emits mandatory before/after audit" do
    before = SystemConfig.get!()

    {:noreply, result} =
      Settings.handle_event(
        "toggle_queue",
        %{"paused" => "true", "base_revision" => to_string(before.document["revision"])},
        socket()
      )

    assert result.assigns.flash["info"] =~ "paused"
    assert SystemConfig.desired()["queue"]["paused"]

    event =
      Repo.one!(
        from e in Event,
          where: e.event_key == "security.admin_config_changed.v2",
          order_by: [desc: e.id],
          limit: 1
      )

    assert Jason.decode!(event.details["before"])["queue"]["paused"] == false
    assert Jason.decode!(event.details["after"])["queue"]["paused"] == true

    revision = SystemConfig.current_revision()

    {:noreply, stale} =
      Settings.handle_event(
        "toggle_queue",
        %{"paused" => "false", "base_revision" => to_string(revision)},
        socket(%{otp_verified_at: System.os_time(:second) - 3600})
      )

    assert {:redirect, %{to: to}} = stale.redirected
    assert to =~ "/admin/otp"
    assert SystemConfig.current_revision() == revision
  end
end

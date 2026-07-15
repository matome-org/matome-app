defmodule MatomeApiWeb.AdminWorkLiveTest do
  use MatomeApiWeb.ConnCase, async: false

  alias MatomeApi.Auth
  alias MatomeApi.Auth.{Device, RefreshToken}
  alias MatomeApi.Content
  alias MatomeApi.Content.{FileBlob, Item}
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig

  @password "correct horse battery staple"

  test "filters observed work and labels stale/unacknowledged device state", %{conn: conn} do
    %{owner: owner, device: device, item: item} = observed_work_fixture()

    old = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

    device
    |> Ecto.Changeset.change(queue_reported_at: old, applied_config_revision: 0)
    |> Repo.update!()

    html = conn |> admin_session() |> get("/admin/work") |> html_response(200)

    assert html =~ "Work"
    assert html =~ "Observation only"
    assert html =~ "No device commands"
    assert html =~ "Stale snapshot"
    assert html =~ "Desired config not acknowledged"
    assert html =~ "Item #{item.id}"
    assert html =~ "Oban accepted"
    assert html =~ "AI not terminal"

    for name <- ~w(stage device media error age) do
      assert html =~ ~s(name="#{name}")
    end

    refute html =~ "Private board meeting"
    refute html =~ "private-board.wav"
    refute html =~ "owners/#{owner.id}/"

    filtered =
      conn
      |> recycle()
      |> admin_session()
      |> get("/admin/work?media=image")
      |> html_response(200)

    refute filtered =~ "Item #{item.id}"

    for query <- [
          "stage=enqueue_processing",
          "device=#{device.id}",
          "error=transport",
          "age=300"
        ] do
      html =
        conn
        |> recycle()
        |> admin_session()
        |> get("/admin/work?#{query}")
        |> html_response(200)

      assert html =~ "Item #{item.id}"
    end

    excluded =
      conn
      |> recycle()
      |> admin_session()
      |> get("/admin/work?device=#{device.id + 1}")
      |> html_response(200)

    refute excluded =~ "Item #{item.id}"
  end

  test "metadata-only drilldown joins current Item, Oban, Events, and device observation", %{
    conn: conn
  } do
    %{item: item, device: device} = observed_work_fixture()

    html =
      conn
      |> admin_session()
      |> get("/admin/work/#{item.id}")
      |> html_response(200)

    assert html =~ "Item #{item.id}"
    assert html =~ item.processing_run_id
    assert html =~ "operational.upload_completed.v1"
    assert html =~ "Device #{device.id}"
    assert html =~ "Oban accepted"
    assert html =~ "AI not terminal"
    assert html =~ "accepted does not mean AI completed"
    refute html =~ "Private board meeting"
    refute html =~ "private-board.wav"
    refute html =~ "X-Amz-"
    refute html =~ "storage_key"
  end

  test "drilldown handles an Item with no processing run", %{conn: conn} do
    {:ok, auth} =
      Auth.register_user(%{
        "email" => "work-pending-#{System.unique_integer([:positive])}@example.com",
        "password" => @password
      })

    {:ok, item} =
      Content.create_file_item(auth.user, nil, %{
        title: "Unprocessed private item",
        byte_size: 1024,
        media_type: "image"
      })

    html =
      conn
      |> admin_session()
      |> get("/admin/work/#{item.id}")
      |> html_response(200)

    assert html =~ "Item #{item.id}"
    assert html =~ "AI not terminal · not_requested"
    refute html =~ "Unprocessed private item"
  end

  test "requires the existing admin session gate", %{conn: conn} do
    assert conn |> get("/admin/work") |> redirected_to() == "/admin/login"
  end

  defp observed_work_fixture do
    {:ok, auth} =
      Auth.register_user(
        %{
          "email" => "work-owner-#{System.unique_integer([:positive])}@example.com",
          "password" => @password
        },
        %{
          device: %{
            "id" => Ecto.UUID.generate(),
            "platform" => "linux",
            "display_name" => "Workstation"
          }
        }
      )

    token = Repo.get_by!(RefreshToken, token: auth.refresh_token)
    device = Repo.get!(Device, token.device_id)

    {:ok, item} =
      Content.create_file_item(auth.user, nil, %{
        title: "Private board meeting",
        filename: "private-board.wav",
        byte_size: 4096,
        checksum_sha256: String.duplicate("a", 64),
        content_type: "audio/wav",
        media_type: "audio"
      })

    item.file_blob
    |> FileBlob.changeset(%{
      upload_state: "uploaded",
      uploaded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update!()

    {:ok, queued} = Content.enqueue_item_processing(auth.user, item.id)

    snapshot = %{
      "counts" => %{"retry" => 1},
      "stages" => %{"enqueue_processing" => 1},
      "errors" => %{"transport" => 1},
      "oldest_age_seconds" => 600,
      "progress" => %{"average" => 0.9, "minimum" => 0.9},
      "items" => [
        %{
          "core_item_id" => item.id,
          "state" => "retry",
          "stage" => "enqueue_processing",
          "media_type" => "audio",
          "age_seconds" => 600,
          "progress" => 0.9,
          "error_code" => "transport"
        }
      ]
    }

    device =
      device
      |> Ecto.Changeset.change(
        queue_snapshot: snapshot,
        queue_reported_at: DateTime.utc_now() |> DateTime.truncate(:second),
        queue_report_sequence: 1,
        applied_config_revision: SystemConfig.current_revision()
      )
      |> Repo.update!()

    %{owner: auth.user, device: device, item: Repo.get!(Item, queued.id)}
  end

  defp admin_session(conn) do
    email = "work-admin@example.com"
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      Keyword.merge(original || [], enabled: true, email_allowlist: [email])
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)
    now = System.os_time(:second)

    Plug.Test.init_test_session(conn, %{
      "admin_email" => email,
      "admin_authenticated_at" => now,
      "admin_otp_verified_at" => now
    })
  end
end

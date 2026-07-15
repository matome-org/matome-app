defmodule MatomeApiWeb.DeviceQueueSnapshotControllerTest do
  use MatomeApiWeb.ConnCase, async: true

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.Auth.{Device, RefreshToken}
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig

  @password "correct horse battery staple"

  test "stores one owner-scoped monotonic sanitized snapshot", %{conn: conn} do
    %{conn: authed, device_id: device_id} = auth_conn(conn)

    authed
    |> post(~p"/api/device/queue-snapshot", report(7))
    |> response(204)

    device = Repo.get!(Device, device_id)
    assert device.queue_report_sequence == 7
    assert device.applied_config_revision == SystemConfig.current_revision()
    assert %DateTime{} = device.queue_reported_at
    assert device.queue_snapshot["counts"] == %{"retry" => 1, "running" => 1}
    assert [%{"core_item_id" => 41}] = device.queue_snapshot["items"]

    authed
    |> post(~p"/api/device/queue-snapshot", put_in(report(6), ["snapshot", "counts"], %{}))
    |> response(204)

    assert Repo.get!(Device, device_id).queue_report_sequence == 7

    assert Repo.get!(Device, device_id).queue_snapshot["counts"] == %{
             "retry" => 1,
             "running" => 1
           }
  end

  test "derives the device from the bearer session and requires a registered device", %{
    conn: conn
  } do
    %{device_id: device_id} = auth_conn(conn)
    %{conn: other} = auth_conn(build_conn())

    other
    |> post(~p"/api/device/queue-snapshot", report(9))
    |> response(204)

    assert is_nil(Repo.get!(Device, device_id).queue_snapshot)

    {:ok, auth} =
      Auth.register_user(%{
        "email" => "queue-no-device-#{System.unique_integer([:positive])}@example.com",
        "password" => @password
      })

    build_conn()
    |> put_req_header("authorization", "Bearer #{auth.access_token}")
    |> post(~p"/api/device/queue-snapshot", report(1))
    |> json_response(422)
    |> then(&assert &1 == %{"error" => "device_not_registered"})
  end

  test "rejects identifiers, content, paths, raw errors, keys, and unknown fields", %{conn: conn} do
    %{conn: authed} = auth_conn(conn)

    forbidden = [
      {"local_id", "rec_local_secret"},
      {"path", "/home/user/private.wav"},
      {"filename", "private.wav"},
      {"title", "Private meeting"},
      {"raw_error", "socket included a signed URL"},
      {"storage_key", "owners/1/private"},
      {"wrapped_key", "ciphertext"}
    ]

    for {key, value} <- forbidden do
      invalid = put_in(report(10), ["snapshot", "items", Access.at(0), key], value)

      authed
      |> post(~p"/api/device/queue-snapshot", invalid)
      |> json_response(422)
      |> then(&assert &1 == %{"error" => "invalid_queue_snapshot"})
    end

    refute Repo.exists?(from d in Device, where: not is_nil(d.queue_snapshot))
  end

  test "bounds item observations and rejects future config acknowledgement", %{conn: conn} do
    %{conn: authed} = auth_conn(conn)

    oversized_items =
      for id <- 1..101 do
        %{
          core_item_id: id,
          state: "queued",
          stage: "upload",
          media_type: "audio",
          age_seconds: 1,
          progress: 0.0,
          error_code: nil
        }
      end

    authed
    |> post(
      ~p"/api/device/queue-snapshot",
      put_in(report(11), ["snapshot", "items"], oversized_items)
    )
    |> json_response(422)

    authed
    |> post(
      ~p"/api/device/queue-snapshot",
      Map.put(report(12), "applied_config_revision", SystemConfig.current_revision() + 1)
    )
    |> json_response(422)
  end

  defp report(sequence) do
    %{
      "contract_version" => "1",
      "sequence" => sequence,
      "applied_config_revision" => SystemConfig.current_revision(),
      "snapshot" => %{
        "counts" => %{"running" => 1, "retry" => 1},
        "stages" => %{"upload" => 2},
        "errors" => %{"transport" => 1},
        "oldest_age_seconds" => 120,
        "progress" => %{"average" => 0.4, "minimum" => 0.2},
        "items" => [
          %{
            "core_item_id" => 41,
            "state" => "running",
            "stage" => "upload",
            "media_type" => "audio",
            "age_seconds" => 120,
            "progress" => 0.4,
            "error_code" => nil
          }
        ]
      }
    }
  end

  defp auth_conn(conn) do
    {:ok, auth} =
      Auth.register_user(
        %{
          "email" => "queue-#{System.unique_integer([:positive])}@example.com",
          "password" => @password
        },
        %{
          device: %{
            "id" => Ecto.UUID.generate(),
            "platform" => "linux",
            "form_factor" => "desktop",
            "device_class" => "desktop"
          }
        }
      )

    token = Repo.get_by!(RefreshToken, token: auth.refresh_token)

    %{
      conn: put_req_header(conn, "authorization", "Bearer #{auth.access_token}"),
      device_id: token.device_id
    }
  end
end

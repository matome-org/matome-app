defmodule MatomeApi.Admin.DashboardTest do
  @moduledoc """
  Admin landing aggregations: 5-minute activity window, platforms, storage.
  """
  use MatomeApi.DataCase, async: true

  import Ecto.Query

  alias MatomeApi.Admin
  alias MatomeApi.Admin.Dashboard
  alias MatomeApi.Auth
  alias MatomeApi.Auth.{Device, RefreshToken}
  alias MatomeApi.Content

  defp register!(email) do
    {:ok, auth} =
      Auth.register_user(%{"email" => email, "password" => "correct horse battery"})

    # Drop the signup session so activity is driven only by seeded devices.
    from(t in RefreshToken, where: t.user_id == ^auth.user.id) |> Repo.delete_all()
    auth.user
  end

  defp insert_device!(user, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Device{}
    |> Device.changeset(
      Map.merge(
        %{
          user_id: user.id,
          client_id: Ecto.UUID.generate(),
          first_seen_at: now,
          last_seen_at: now
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  describe "activity_window_seconds/0" do
    test "is five minutes" do
      assert Dashboard.activity_window_seconds() == 300
      assert Admin.activity_window_seconds() == 300
    end
  end

  describe "stats/1" do
    test "classifies users and devices at the 5-minute boundary" do
      now = ~U[2026-07-09 12:00:00Z]
      active_user = register!("dash-active@example.com")
      inactive_user = register!("dash-inactive@example.com")
      _never_seen = register!("dash-never@example.com")

      insert_device!(active_user, %{
        platform: "ios",
        last_seen_at: DateTime.add(now, -299, :second)
      })

      insert_device!(inactive_user, %{
        platform: "android",
        last_seen_at: DateTime.add(now, -301, :second)
      })

      # Second device for active user — stale, still counts as inactive device.
      insert_device!(active_user, %{
        platform: "web",
        last_seen_at: DateTime.add(now, -600, :second)
      })

      stats = Admin.dashboard_stats(now)

      assert stats.users.total == 3
      assert stats.users.active == 1
      assert stats.users.inactive == 2

      assert stats.devices.total == 3
      assert stats.devices.active == 1
      assert stats.devices.inactive == 2
    end

    test "maps blank platform to unknown and sorts by count" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      user = register!("dash-platform@example.com")

      insert_device!(user, %{platform: "ios", last_seen_at: now})
      insert_device!(user, %{platform: "ios", last_seen_at: now})
      insert_device!(user, %{platform: nil, last_seen_at: now})
      insert_device!(user, %{platform: "  ", last_seen_at: now})

      %{platforms: platforms} = Admin.dashboard_stats(now)

      assert platforms == [
               %{platform: "ios", count: 2},
               %{platform: "unknown", count: 2}
             ]
    end

    test "groups form_factor and device_class with unknown for blanks" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      user = register!("dash-axes@example.com")

      insert_device!(user, %{
        platform: "linux",
        form_factor: "desktop",
        device_class: "laptop",
        last_seen_at: now
      })

      insert_device!(user, %{
        platform: "android",
        form_factor: "mobile",
        device_class: "smartphone",
        last_seen_at: now
      })

      insert_device!(user, %{platform: "web", last_seen_at: now})

      stats = Admin.dashboard_stats(now)

      assert Enum.find(stats.form_factors, &(&1.form_factor == "desktop")).count == 1
      assert Enum.find(stats.form_factors, &(&1.form_factor == "mobile")).count == 1
      assert Enum.find(stats.form_factors, &(&1.form_factor == "unknown")).count == 1

      assert Enum.find(stats.device_classes, &(&1.device_class == "laptop")).count == 1
      assert Enum.find(stats.device_classes, &(&1.device_class == "smartphone")).count == 1
      assert Enum.find(stats.device_classes, &(&1.device_class == "unknown")).count == 1
    end

    test "sums workspace and unfiled file blob bytes" do
      owner = register!("dash-storage@example.com")
      {:ok, workspace} = Content.create_workspace(owner, %{name: "Research"})

      {:ok, filed} =
        Content.create_matome(owner, %{title: "Filed", workspace_id: workspace.id})

      {:ok, unfiled} = Content.create_matome(owner, %{title: "Inbox"})

      assert {:ok, _} =
               Content.create_file_item(owner, filed.id, %{
                 media_type: "audio",
                 byte_size: 10_000_000
               })

      assert {:ok, _} =
               Content.create_file_item(owner, unfiled.id, %{
                 media_type: "audio",
                 byte_size: 2_500_000
               })

      assert {:ok, _} =
               Content.create_file_item(owner, nil, %{
                 workspace_id: workspace.id,
                 media_type: "audio",
                 byte_size: 750_000
               })

      assert {:ok, _} =
               Content.create_file_item(owner, nil, %{
                 media_type: "audio",
                 byte_size: 250_000
               })

      assert {:ok, _} =
               Content.create_file_item(owner, unfiled.id, %{
                 workspace_id: workspace.id,
                 media_type: "audio",
                 byte_size: 125_000
               })

      %{storage: storage} = Admin.dashboard_stats()

      assert storage.total_bytes == 13_625_000
      assert storage.unfiled_bytes == 2_875_000

      research = Enum.find(storage.by_workspace, &(&1.name == "Research"))
      assert research.bytes == 10_750_000
    end
  end
end

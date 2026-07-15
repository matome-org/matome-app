defmodule MatomeApi.AdminSessionsTest do
  @moduledoc """
  W6 (#1874) context layer: the §9.2 session tree (user → device → active
  tokens) and the audited admin revoke that feeds the Sessions LiveView.
  """
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Admin
  alias MatomeApi.Auth
  alias MatomeApi.Auth.RefreshToken
  alias MatomeApi.Events.Event

  defp register!(email, meta \\ %{}) do
    {:ok, auth} =
      Auth.register_user(%{"email" => email, "password" => "correct horse battery"}, meta)

    auth
  end

  defp make_admin!(user) do
    user |> Ecto.Changeset.change(role: "admin") |> Repo.update!()
  end

  defp stored_token(refresh_token) do
    Repo.get_by!(RefreshToken, token: refresh_token)
  end

  describe "session_tree/1" do
    test "groups active tokens under user and device" do
      device_id = Ecto.UUID.generate()

      %{user: user} =
        register!("tree-user@example.com", %{
          ip: "203.0.113.7",
          user_agent: "MatomeApp/1.0 (linux)",
          login_method: "password",
          device: %{
            "id" => device_id,
            "platform" => "linux",
            "display_name" => "Dev laptop"
          }
        })

      # A second, deviceless session for the same user (no UA either).
      {:ok, _} = Auth.login(user.email, "correct horse battery", %{ip: "198.51.100.9"})

      assert [%{user: tree_user, last_seen_at: %DateTime{}, devices: devices}] =
               Admin.session_tree()

      assert tree_user.id == user.id
      assert length(devices) == 2

      named = Enum.find(devices, & &1.device)
      anonymous = Enum.find(devices, &is_nil(&1.device))

      assert named.device.display_name == "Dev laptop"
      assert [%RefreshToken{ip: "203.0.113.7", login_method: "password"}] = named.tokens
      assert [%RefreshToken{ip: "198.51.100.9"}] = anonymous.tokens
    end

    test "excludes revoked and expired tokens, and empty users" do
      %{user: user, refresh_token: refresh_token} = register!("revoked-user@example.com")

      # Expired token row for the same user.
      past = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      %RefreshToken{}
      |> RefreshToken.changeset(%{
        token: "expired-#{System.unique_integer([:positive])}",
        user_id: user.id,
        expires_at: past,
        jti: Ecto.UUID.generate()
      })
      |> Repo.insert!()

      :ok = Auth.logout(refresh_token)

      assert Admin.session_tree() == []
    end

    test "orders users by most recent activity" do
      %{user: older} = register!("older@example.com")
      %{user: newer} = register!("newer@example.com")

      # Push the older user's activity into the past.
      past = DateTime.utc_now() |> DateTime.add(-7200) |> DateTime.truncate(:second)

      from(t in RefreshToken, where: t.user_id == ^older.id)
      |> Repo.update_all(set: [last_seen_at: past])

      assert [%{user: first}, %{user: second}] = Admin.session_tree()
      assert first.id == newer.id
      assert second.id == older.id
    end
  end

  describe "revoke_session/3" do
    test "revokes the whole family, audits, and returns :ok" do
      %{user: user, refresh_token: refresh_token} = register!("revokee@example.com")
      admin = register!("the-admin@example.com").user |> make_admin!()

      # Rotate once so the family has two rows (one already revoked).
      {:ok, %{refresh_token: rotated}} = Auth.refresh(refresh_token)
      %RefreshToken{jti: jti, family_id: family_id} = stored_token(rotated)

      assert :ok = Admin.revoke_session(admin, jti, remote_ip: "192.0.2.1")

      live_in_family =
        from(t in RefreshToken,
          where: t.family_id == ^family_id and is_nil(t.revoked_at)
        )
        |> Repo.aggregate(:count)

      assert live_in_family == 0

      audit =
        Repo.one!(
          from e in Event,
            where: e.event_key == "security.admin.session_revoked.v1"
        )

      assert audit.actor_id == admin.id
      assert audit.remote_ip == "192.0.2.1"
      assert audit.subject_type == "session"
      assert audit.subject_id == jti
      assert audit.owner_id == user.id
    end

    test "returns {:error, :not_found} for an unknown jti and audits nothing" do
      admin = register!("lost-admin@example.com").user |> make_admin!()

      assert {:error, :not_found} =
               Admin.revoke_session(admin, Ecto.UUID.generate(), remote_ip: nil)

      refute Repo.exists?(
               from e in Event,
                 where: e.event_key == "security.admin.session_revoked.v1"
             )
    end
  end
end

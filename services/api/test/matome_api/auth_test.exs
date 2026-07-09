defmodule MatomeApi.AuthTest do
  use MatomeApi.DataCase, async: true

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.Auth.{Device, RefreshToken}
  alias MatomeApi.Repo

  @password "correct horse battery staple"
  @meta %{
    ip: "203.0.113.9",
    user_agent: "MatomeTest/1.0 (Linux)",
    login_method: "password",
    device: %{
      "id" => "8f3c9a4e-1c2b-4d5e-9f6a-7b8c9d0e1f2a",
      "platform" => "linux",
      "display_name" => "Howl's laptop"
    }
  }

  describe "login/2 user-enumeration timing hardening (okt-audit AUDIT-CORE, task #1865)" do
    test "wrong password for a real account returns :invalid_credentials" do
      email = unique_email()
      {:ok, _auth} = Auth.register_user(%{"email" => email, "password" => @password})

      assert Auth.login(email, "definitely not it") == {:error, :invalid_credentials}
    end

    test "a nonexistent email returns the same error shape as a wrong password" do
      assert Auth.login(unique_email(), "whatever") == {:error, :invalid_credentials}
    end

    test "both the real-account and no-such-account branches pay comparable Argon2 cost" do
      email = unique_email()
      {:ok, _auth} = Auth.register_user(%{"email" => email, "password" => @password})

      # Warm up the Argon2 NIF/scheduler once before timing so a one-off JIT
      # /first-call cost doesn't skew the very first measurement.
      Auth.login(email, "warmup")

      {existing_us, {:error, :invalid_credentials}} =
        :timer.tc(fn -> Auth.login(email, "definitely not it") end)

      {missing_us, {:error, :invalid_credentials}} =
        :timer.tc(fn -> Auth.login(unique_email(), "whatever") end)

      # Not a tight timing-attack assertion (inherently flaky under CI
      # scheduling jitter) — just a coarse regression guard that the
      # no-such-account branch isn't a near-instant short-circuit anymore.
      # Before this fix it returned in a small fraction of the hashed
      # branch's time (no Argon2 call at all); now both call into Argon2
      # once, so neither should be more than ~3x faster than the other.
      assert missing_us > existing_us / 3
      assert existing_us > missing_us / 3
    end
  end

  describe "login/3 session-metadata capture (W4 #1872)" do
    test "populates token metadata and a device row" do
      email = unique_email()
      {:ok, _} = Auth.register_user(%{"email" => email, "password" => @password})

      {:ok, %{user: user}} = Auth.login(email, @password, @meta)

      token = latest_token(user)
      assert token.ip == "203.0.113.9"
      assert token.user_agent == "MatomeTest/1.0 (Linux)"
      assert token.login_method == "password"
      assert is_binary(token.jti)
      assert is_binary(token.family_id)
      assert %DateTime{} = token.last_seen_at
      assert token.revoked_at == nil

      device = Repo.get!(Device, token.device_id)
      assert device.user_id == user.id
      assert device.client_id == "8f3c9a4e-1c2b-4d5e-9f6a-7b8c9d0e1f2a"
      assert device.platform == "linux"
      assert device.display_name == "Howl's laptop"
      assert device.user_agent == "MatomeTest/1.0 (Linux)"
      assert %DateTime{} = device.first_seen_at
      assert %DateTime{} = device.last_seen_at
      assert device.device_key_enrolled == false
      assert device.revoked_at == nil
    end

    test "re-login with the same client device id correlates instead of duplicating" do
      email = unique_email()
      {:ok, _} = Auth.register_user(%{"email" => email, "password" => @password})

      {:ok, %{user: user}} = Auth.login(email, @password, @meta)
      first = Repo.one!(from(d in Device, where: d.user_id == ^user.id))

      updated_meta = put_in(@meta, [:device, "display_name"], "Renamed laptop")
      {:ok, _} = Auth.login(email, @password, updated_meta)

      assert [device] = Repo.all(from(d in Device, where: d.user_id == ^user.id))
      assert device.id == first.id
      assert device.display_name == "Renamed laptop"
      assert device.first_seen_at == first.first_seen_at
    end

    test "without a client device id, correlation falls back to the user agent" do
      email = unique_email()
      {:ok, _} = Auth.register_user(%{"email" => email, "password" => @password})
      meta = Map.put(@meta, :device, nil)

      {:ok, %{user: user}} = Auth.login(email, @password, meta)
      {:ok, _} = Auth.login(email, @password, meta)

      assert [device] = Repo.all(from(d in Device, where: d.user_id == ^user.id))
      assert device.client_id == nil
      assert device.user_agent == meta.user_agent

      # A different user agent is a different (unidentified) device.
      {:ok, _} = Auth.login(email, @password, %{meta | user_agent: "Other/2.0"})
      assert length(Repo.all(from(d in Device, where: d.user_id == ^user.id))) == 2
    end

    test "an unparseable client device id degrades to user-agent correlation" do
      email = unique_email()
      {:ok, _} = Auth.register_user(%{"email" => email, "password" => @password})
      meta = put_in(@meta, [:device, "id"], "not-a-uuid")

      {:ok, %{user: user}} = Auth.login(email, @password, meta)

      assert [device] = Repo.all(from(d in Device, where: d.user_id == ^user.id))
      assert device.client_id == nil
      assert latest_token(user).device_id == device.id
    end

    test "with no metadata at all (legacy call), tokens still work and start a family" do
      email = unique_email()
      {:ok, _} = Auth.register_user(%{"email" => email, "password" => @password})

      {:ok, %{user: user}} = Auth.login(email, @password)

      token = latest_token(user)
      assert is_binary(token.jti)
      assert is_binary(token.family_id)
      assert token.device_id == nil
      assert token.ip == nil
      assert Repo.all(from(d in Device, where: d.user_id == ^user.id)) == []
    end
  end

  describe "refresh/2 rotation chain (W4 #1872)" do
    test "rotation keeps the family, links jti chain, and retains the old row revoked" do
      email = unique_email()

      {:ok, %{user: user, refresh_token: refresh_token}} =
        Auth.register_user(%{"email" => email, "password" => @password}, @meta)

      old = latest_token(user)

      {:ok, %{refresh_token: new_refresh_token}} =
        Auth.refresh(refresh_token, %{ip: "198.51.100.4", user_agent: "MatomeTest/1.1"})

      assert new_refresh_token != refresh_token

      new_token = Repo.get_by!(RefreshToken, token: new_refresh_token)
      assert new_token.family_id == old.family_id
      assert new_token.rotated_from == old.jti
      assert new_token.jti != old.jti
      assert new_token.login_method == old.login_method
      assert new_token.device_id == old.device_id
      assert new_token.ip == "198.51.100.4"
      assert new_token.user_agent == "MatomeTest/1.1"

      # The rotated token is retained (revoked), not deleted — the W5
      # replay-detection seam.
      rotated = Repo.get_by!(RefreshToken, token: refresh_token)
      assert %DateTime{} = rotated.revoked_at
    end

    test "refresh bumps the device last_seen_at" do
      email = unique_email()

      {:ok, %{user: user, refresh_token: refresh_token}} =
        Auth.register_user(%{"email" => email, "password" => @password}, @meta)

      device = Repo.one!(from(d in Device, where: d.user_id == ^user.id))
      backdated = DateTime.add(device.last_seen_at, -3600, :second)

      {1, _} =
        Repo.update_all(from(d in Device, where: d.id == ^device.id),
          set: [last_seen_at: backdated]
        )

      {:ok, _} = Auth.refresh(refresh_token, %{})

      refreshed = Repo.get!(Device, device.id)
      assert DateTime.compare(refreshed.last_seen_at, backdated) == :gt
    end

    test "a revoked refresh token is rejected (W5 revocation seam)" do
      email = unique_email()

      {:ok, %{refresh_token: refresh_token}} =
        Auth.register_user(%{"email" => email, "password" => @password}, @meta)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {1, _} =
        Repo.update_all(from(t in RefreshToken, where: t.token == ^refresh_token),
          set: [revoked_at: now]
        )

      assert Auth.refresh(refresh_token, %{}) == {:error, :invalid_refresh_token}
    end
  end

  defp latest_token(user) do
    Repo.one!(
      from(t in RefreshToken,
        where: t.user_id == ^user.id and is_nil(t.revoked_at),
        order_by: [desc: t.id],
        limit: 1
      )
    )
  end

  defp unique_email do
    "user-#{System.unique_integer([:positive])}@example.com"
  end
end

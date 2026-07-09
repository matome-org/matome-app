defmodule MatomeApi.AdminTest do
  @moduledoc """
  W3 #1871 — the admin access-control context: hard role allowlist, TOTP
  enrollment + verification with replay rejection and attempt lockout, and
  day-one audit writes.
  """
  use MatomeApi.DataCase, async: false

  alias MatomeApi.Admin
  alias MatomeApi.Admin.{AuditEvent, TOTP, TotpSecret}
  alias MatomeApi.Auth
  alias MatomeApi.Auth.User

  @password "correct horse battery staple"

  defp create_user!(role \\ "user") do
    email = "w3-#{System.unique_integer([:positive])}@example.com"
    {:ok, %{user: user}} = Auth.register_user(%{"email" => email, "password" => @password})
    user |> Ecto.Changeset.change(role: role) |> Repo.update!()
  end

  defp enroll!(user) do
    {:ok, secret} = Admin.start_totp_enrollment(user)
    now = System.os_time(:second)
    code = NimbleTOTP.verification_code(secret, time: now)
    :ok = Admin.confirm_totp_enrollment(user, code, now: now)
    secret
  end

  describe "role allowlist" do
    test "registration NEVER grants a privileged role, even if asked to" do
      {:ok, %{user: user}} =
        Auth.register_user(%{
          "email" => "sneaky-#{System.unique_integer([:positive])}@example.com",
          "password" => @password,
          "role" => "admin"
        })

      assert Repo.get!(User, user.id).role == "user"
    end

    test "admin?/1 accepts only admin and superadmin" do
      refute Admin.admin?(create_user!("user"))
      assert Admin.admin?(create_user!("admin"))
      assert Admin.admin?(create_user!("superadmin"))
    end

    test "the DB refuses unknown roles" do
      user = create_user!()

      assert_raise Postgrex.Error, ~r/users_role_must_be_known/, fn ->
        Repo.query!("UPDATE users SET role = 'root' WHERE id = $1", [user.id])
      end
    end
  end

  describe "authenticate_admin/2" do
    test "authenticates an admin with the right password" do
      user = create_user!("admin")
      assert {:ok, %User{id: id}} = Admin.authenticate_admin(user.email, @password)
      assert id == user.id
    end

    test "rejects a wrong password" do
      user = create_user!("admin")
      assert {:error, :invalid_credentials} = Admin.authenticate_admin(user.email, "wrong")
    end

    test "rejects a non-admin with the RIGHT password, indistinguishably" do
      user = create_user!("user")
      assert {:error, :invalid_credentials} = Admin.authenticate_admin(user.email, @password)
    end

    test "rejects an unknown email" do
      assert {:error, :invalid_credentials} = Admin.authenticate_admin("nobody@example.com", @password)
    end
  end

  describe "TOTP enrollment" do
    test "start + confirm round-trip enables TOTP" do
      user = create_user!("admin")
      refute Admin.totp_enabled?(user)

      enroll!(user)

      assert Admin.totp_enabled?(user)
    end

    test "the stored secret is encrypted at rest (ciphertext != plaintext)" do
      user = create_user!("admin")
      secret = enroll!(user)

      row = Repo.get_by!(TotpSecret, user_id: user.id)
      refute row.secret_ciphertext == secret
      assert {:ok, ^secret} = MatomeApi.Admin.SecretVault.decrypt(row.secret_ciphertext)
    end

    test "start is idempotent while unconfirmed, refused once enrolled" do
      user = create_user!("admin")

      {:ok, secret} = Admin.start_totp_enrollment(user)
      {:ok, ^secret} = Admin.start_totp_enrollment(user)

      now = System.os_time(:second)
      :ok = Admin.confirm_totp_enrollment(user, NimbleTOTP.verification_code(secret, time: now), now: now)

      assert {:error, :already_enrolled} = Admin.start_totp_enrollment(user)
    end

    test "confirm rejects a wrong code and stays unconfirmed" do
      user = create_user!("admin")
      {:ok, _secret} = Admin.start_totp_enrollment(user)

      assert {:error, :invalid_code} = Admin.confirm_totp_enrollment(user, "000000")
      refute Admin.totp_enabled?(user)
    end
  end

  describe "verify_totp/3" do
    test "accepts a valid current code" do
      user = create_user!("admin")
      secret = enroll!(user)

      now = System.os_time(:second) + 300
      code = NimbleTOTP.verification_code(secret, time: now)

      assert :ok = Admin.verify_totp(user, code, now: now)
    end

    test "rejects an invalid code" do
      user = create_user!("admin")
      enroll!(user)

      assert {:error, :invalid_code} = Admin.verify_totp(user, "000000")
    end

    test "rejects a user with no confirmed enrollment" do
      user = create_user!("admin")
      {:ok, secret} = Admin.start_totp_enrollment(user)
      code = NimbleTOTP.verification_code(secret)

      assert {:error, :invalid_code} = Admin.verify_totp(user, code)
    end

    test "REPLAY: the same code is rejected the second time" do
      user = create_user!("admin")
      secret = enroll!(user)

      now = System.os_time(:second) + 300
      code = NimbleTOTP.verification_code(secret, time: now)

      assert :ok = Admin.verify_totp(user, code, now: now)
      assert {:error, :invalid_code} = Admin.verify_totp(user, code, now: now)
    end

    test "REPLAY: an older timestep's code is rejected after a newer one was used" do
      user = create_user!("admin")
      secret = enroll!(user)

      now = System.os_time(:second) + 300
      newer = NimbleTOTP.verification_code(secret, time: now)
      older = NimbleTOTP.verification_code(secret, time: now - 30)

      assert :ok = Admin.verify_totp(user, newer, now: now)
      # `older` is still inside the ±1 skew window, but its timestep is
      # below the high-water mark — must be rejected.
      assert {:error, :invalid_code} = Admin.verify_totp(user, older, now: now)
    end

    test "a LATER code still works after an earlier one (high-water mark moves)" do
      user = create_user!("admin")
      secret = enroll!(user)

      now = System.os_time(:second) + 300

      assert :ok = Admin.verify_totp(user, NimbleTOTP.verification_code(secret, time: now), now: now)

      later = now + 60

      assert :ok =
               Admin.verify_totp(user, NimbleTOTP.verification_code(secret, time: later), now: later)
    end

    test "LOCKOUT: repeated failures lock the account out, even for a then-valid code" do
      user = create_user!("admin")
      secret = enroll!(user)
      now = System.os_time(:second) + 300

      for _ <- 1..6 do
        Admin.verify_totp(user, "000000", now: now)
      end

      code = NimbleTOTP.verification_code(secret, time: now)
      assert {:error, :rate_limited} = Admin.verify_totp(user, code, now: now)
    end
  end

  describe "audit!/2" do
    test "writes an append-only row with actor snapshot" do
      user = create_user!("admin")

      event =
        Admin.audit!("admin.login", actor: user, metadata: %{"path" => "/admin"}, remote_ip: "127.0.0.1")

      assert %AuditEvent{} = event
      assert event.actor_id == user.id
      assert event.actor_email == user.email
      assert event.action == "admin.login"
      assert event.metadata == %{"path" => "/admin"}
      assert event.remote_ip == "127.0.0.1"
    end

    test "accepts events without an actor (e.g. failed login for unknown email)" do
      event = Admin.audit!("admin.login_failed", metadata: %{"email" => "x@example.com"})

      assert event.actor_id == nil
      assert event.action == "admin.login_failed"
    end
  end

  test "otpauth_uri embeds issuer and account" do
    uri = TOTP.otpauth_uri(TOTP.generate_secret(), "root@example.com")

    assert uri =~ "otpauth://totp/"
    assert uri =~ "issuer=matome"
    assert uri =~ "root@example.com"
  end
end

defmodule MatomeApi.AdminUsersAuditTest do
  @moduledoc """
  W7 (#1875) context layer: the §9.6 users directory (methods / MFA /
  last-login) and the filtered `admin_audit_events` reader that feed the
  Users + Audit LiveViews.
  """
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Admin
  alias MatomeApi.Admin.AuditEvent
  alias MatomeApi.Auth
  alias MatomeApi.Auth.RefreshToken

  defp register!(email, meta \\ %{}) do
    {:ok, auth} =
      Auth.register_user(%{"email" => email, "password" => "correct horse battery"}, meta)

    auth
  end

  defp confirm_totp!(user) do
    %MatomeApi.Admin.TotpSecret{}
    |> MatomeApi.Admin.TotpSecret.changeset(%{
      user_id: user.id,
      secret_ciphertext: <<9, 9, 9, 9>>,
      confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  describe "list_users/0" do
    test "returns every user with login methods, MFA flag, and last login" do
      %{user: with_mfa} =
        register!("mfa-user@example.com", %{
          login_method: "password",
          ip: "203.0.113.10"
        })

      confirm_totp!(with_mfa)

      # Second method on the same account (e.g. a later TOTP-gated login).
      {:ok, _} =
        Auth.login(with_mfa.email, "correct horse battery", %{
          login_method: "totp+password",
          ip: "198.51.100.20"
        })

      %{user: bare} = register!("bare-user@example.com")

      rows = Admin.list_users()

      mfa_row = Enum.find(rows, &(&1.user.id == with_mfa.id))
      bare_row = Enum.find(rows, &(&1.user.id == bare.id))

      assert mfa_row.mfa_enabled == true
      assert Enum.sort(mfa_row.login_methods) == ["password", "totp+password"]
      assert %DateTime{} = mfa_row.last_login_at

      assert bare_row.mfa_enabled == false
      # Registration mints a refresh token with no login_method by default.
      assert is_list(bare_row.login_methods)
      assert %DateTime{} = bare_row.last_login_at
    end

    test "orders by most recent login descending" do
      older = register!("older@example.com")
      newer = register!("newer@example.com")

      past = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      older_token = Repo.get_by!(RefreshToken, user_id: older.user.id)

      older_token
      |> Ecto.Changeset.change(last_seen_at: past)
      |> Repo.update!()

      [first | _] = Admin.list_users()
      assert first.user.id == newer.user.id
    end
  end

  describe "list_audit_events/1" do
    test "returns newest-first and filters by admin, action, target, time" do
      admin_a =
        register!("auditor-a@example.com").user
        |> Ecto.Changeset.change(role: "admin")
        |> Repo.update!()

      admin_b =
        register!("auditor-b@example.com").user
        |> Ecto.Changeset.change(role: "admin")
        |> Repo.update!()

      early = ~U[2026-01-01 10:00:00.000000Z]
      mid = ~U[2026-01-02 10:00:00.000000Z]
      late = ~U[2026-01-03 10:00:00.000000Z]

      insert_audit!(admin_a, "admin.login", %{"target" => "self"}, early)
      insert_audit!(admin_a, "admin.session_revoked", %{"user_id" => 42, "jti" => "abc"}, mid)
      insert_audit!(admin_b, "admin.logout", %{"target" => "self"}, late)

      all = Admin.list_audit_events()
      assert Enum.map(all, & &1.action) == [
               "admin.logout",
               "admin.session_revoked",
               "admin.login"
             ]

      by_admin = Admin.list_audit_events(actor_id: admin_a.id)
      assert Enum.map(by_admin, & &1.action) == ["admin.session_revoked", "admin.login"]

      by_email = Admin.list_audit_events(actor_email: admin_a.email)
      assert Enum.map(by_email, & &1.action) == ["admin.session_revoked", "admin.login"]

      by_action = Admin.list_audit_events(action: "admin.logout")
      assert length(by_action) == 1
      assert hd(by_action).actor_id == admin_b.id
      assert hd(by_action).actor_email == admin_b.email

      by_target = Admin.list_audit_events(target: "42")
      assert length(by_target) == 1
      assert hd(by_target).action == "admin.session_revoked"

      by_time = Admin.list_audit_events(since: mid, until: late)
      assert Enum.map(by_time, & &1.action) == ["admin.session_revoked"]
    end

    test "blank filters are no-ops" do
      Admin.audit!("admin.login", metadata: %{"email" => "x@example.com"})

      assert length(
               Admin.list_audit_events(
                 actor_id: nil,
                 actor_email: "",
                 action: "",
                 target: "  "
               )
             ) == 1
    end
  end

  defp insert_audit!(actor, action, metadata, inserted_at) do
    %AuditEvent{}
    |> AuditEvent.changeset(%{
      actor_id: actor.id,
      actor_email: actor.email,
      action: action,
      metadata: metadata
    })
    |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
    |> Repo.insert!()
  end
end

defmodule MatomeApi.AdminUsersAuditTest do
  @moduledoc """
  W7 (#1875) context layer: the §9.6 users directory (methods / MFA /
  last-login) and the filtered security event reader that feed the
  Users + Audit LiveViews.
  """
  use MatomeApi.DataCase, async: true

  alias MatomeApi.Admin
  alias MatomeApi.Auth
  alias MatomeApi.Auth.RefreshToken
  alias MatomeApi.Events
  alias MatomeApi.Events.Event

  defp read_opts(extra \\ []) do
    Keyword.merge(
      [actor: %{email: "admin@example.com"}, remote_ip: "192.0.2.20"],
      extra
    )
  end

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

      rows = Admin.list_users(read_opts())

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

      [first | _] = Admin.list_users(read_opts())
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

      all = Admin.list_audit_events(read_opts())

      assert Enum.map(all, & &1.event_key) == [
               "security.admin.logout.v1",
               "security.admin.session_revoked.v2",
               "security.admin.login.v1"
             ]

      by_admin = Admin.list_audit_events(read_opts(actor_id: admin_a.id))

      assert Enum.map(by_admin, & &1.event_key) == [
               "security.admin.session_revoked.v2",
               "security.admin.login.v1"
             ]

      by_email = Admin.list_audit_events(read_opts(actor_email: admin_a.email))

      assert Enum.map(by_email, & &1.event_key) == [
               "security.admin.session_revoked.v2",
               "security.admin.login.v1"
             ]

      by_action = Admin.list_audit_events(read_opts(action: "admin.logout"))
      assert length(by_action) == 1
      assert hd(by_action).actor_id == admin_b.id
      assert hd(by_action).actor_email == admin_b.email

      by_target = Admin.list_audit_events(read_opts(target: "42"))
      assert length(by_target) == 1
      assert hd(by_target).event_key == "security.admin.session_revoked.v2"

      by_time = Admin.list_audit_events(read_opts(since: mid, until: late))
      assert Enum.map(by_time, & &1.event_key) == ["security.admin.session_revoked.v2"]
    end

    test "blank filters are no-ops" do
      Admin.audit!("admin.login", metadata: %{"via" => "otp"})

      assert length(
               Admin.list_audit_events(
                 read_opts(
                   actor_id: nil,
                   actor_email: "",
                   action: "",
                   target: "  "
                 )
               )
             ) == 1
    end
  end

  defp insert_audit!(actor, action, metadata, inserted_at) do
    {:ok, event_key} = Events.admin_event_key(action)

    attrs =
      case action do
        "admin.session_revoked" ->
          %{
            subject_type: "user",
            subject_id: to_string(metadata["user_id"]),
            details: %{"before" => "active", "after" => "revoked"}
          }

        "admin.login" ->
          %{details: %{"via" => metadata["target"]}}

        _action ->
          %{details: %{}}
      end

    %Event{event_key: event_key}
    |> Event.changeset(
      Map.merge(attrs, %{
        actor_id: actor.id,
        actor_email: actor.email,
        occurred_at: inserted_at
      })
    )
    |> Repo.insert!()
  end
end

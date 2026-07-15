defmodule MatomeApi.AdminTest do
  @moduledoc """
  Admin email-OTP context: allowlist, one-shot OTP, audit writes.
  """
  use MatomeApi.DataCase, async: false

  import Ecto.Query
  import Swoosh.TestAssertions

  alias MatomeApi.Admin
  alias MatomeApi.Admin.{LoginOtp, NetworkPolicy}
  alias MatomeApi.Auth
  alias MatomeApi.Auth.User
  alias MatomeApi.Events.Event

  @allowlisted "otp-admin@example.com"

  setup do
    original = Application.get_env(:matome_api, :admin_panel)

    Application.put_env(
      :matome_api,
      :admin_panel,
      enabled: true,
      email_allowlist: [@allowlisted]
    )

    on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)
    :ok
  end

  defp receive_code! do
    receive do
      {:email, %Swoosh.Email{} = email} ->
        [_, code] = Regex.run(~r/\b(\d{6})\b/, email.text_body)
        code
    after
      1_000 -> flunk("expected OTP email")
    end
  end

  describe "email allowlist" do
    test "email_allowed?/1 matches the env allowlist" do
      assert Admin.email_allowed?(@allowlisted)
      assert Admin.email_allowed?(String.upcase(@allowlisted))
      refute Admin.email_allowed?("stranger@example.com")
    end

    test "registration NEVER grants a privileged role, even if asked to" do
      {:ok, %{user: user}} =
        Auth.register_user(%{
          "email" => "sneaky-#{System.unique_integer([:positive])}@example.com",
          "password" => "correct horse battery staple",
          "role" => "admin"
        })

      assert Repo.get!(User, user.id).role == "user"
    end
  end

  describe "request_login_otp/2" do
    test "allowlisted email stores a peppered hash and delivers mail" do
      assert {:ok, :sent} = Admin.request_login_otp(@allowlisted, remote_ip: "127.0.0.1")
      code = receive_code!()
      assert String.length(code) == 6

      otp = Repo.get_by!(LoginOtp, email: @allowlisted)

      pepper =
        Application.fetch_env!(:matome_api, :admin_otp)
        |> Keyword.fetch!(:pepper)

      assert otp.code_hash == :crypto.mac(:hmac, :sha256, pepper, code)
      assert is_nil(otp.consumed_at)
      assert NetworkPolicy.email_allowed?(@allowlisted)
    end

    test "OTP generation uses the cryptographic RNG" do
      source = File.read!(Path.expand("../../lib/matome_api/admin.ex", __DIR__))

      assert source =~ ":crypto.strong_rand_bytes"
      refute source =~ ":rand.uniform"
    end

    test "non-allowlisted email is silent — no row, no mail" do
      assert :silent = Admin.request_login_otp("nope@example.com")
      refute Repo.exists?(from o in LoginOtp, where: o.email == "nope@example.com")
      refute_email_sent()
    end
  end

  describe "verify_login_otp/2" do
    test "accepts a fresh code once" do
      assert {:ok, :sent} = Admin.request_login_otp(@allowlisted)
      code = receive_code!()

      assert {:ok, @allowlisted} = Admin.verify_login_otp(@allowlisted, code)
      assert {:error, :invalid_code} = Admin.verify_login_otp(@allowlisted, code)
    end

    test "rejects a wrong code" do
      assert {:ok, :sent} = Admin.request_login_otp(@allowlisted)
      _ = receive_code!()
      assert {:error, :invalid_code} = Admin.verify_login_otp(@allowlisted, "000000")
    end

    test "rejects when email is not allowlisted" do
      assert {:error, :invalid_code} = Admin.verify_login_otp("nope@example.com", "123456")
    end

    test "mandatory login event failure does not consume the code" do
      assert {:ok, :sent} = Admin.request_login_otp(@allowlisted)
      code = receive_code!()

      assert {:error, {:audit_failed, _changeset}} =
               Admin.verify_login_otp(@allowlisted, code, remote_ip: String.duplicate("1", 65))

      assert {:ok, @allowlisted} =
               Admin.verify_login_otp(@allowlisted, code, remote_ip: "127.0.0.1")
    end
  end

  describe "audit!/2" do
    test "writes actor_email without requiring a users row" do
      event =
        Admin.audit!("admin.login",
          actor: %{email: @allowlisted},
          remote_ip: "127.0.0.1",
          metadata: %{"via" => "otp"}
        )

      assert %Event{
               actor_id: nil,
               actor_email: @allowlisted,
               event_key: "security.admin.login.v1"
             } = event

      assert event.details["via"] == "otp"
    end
  end
end

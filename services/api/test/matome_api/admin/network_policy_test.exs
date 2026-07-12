defmodule MatomeApi.Admin.NetworkPolicyTest do
  @moduledoc """
  Soft IP tier + email allowlist + client IP resolution for /admin.
  """
  use ExUnit.Case, async: true

  alias MatomeApi.Admin.NetworkPolicy

  @allow ["10.8.0.0/24", "127.0.0.1/32"]
  @proxies ["172.16.0.0/16"]

  describe "soft_trusted_ip?/3" do
    test "empty allowlist trusts every resolvable client" do
      assert NetworkPolicy.soft_trusted_ip?({203, 0, 113, 5}, [],
               allowlist: [],
               trusted_proxies: []
             )
    end

    test "non-empty allowlist trusts only listed CIDRs" do
      assert NetworkPolicy.soft_trusted_ip?({10, 8, 0, 7}, [],
               allowlist: @allow,
               trusted_proxies: []
             )

      refute NetworkPolicy.soft_trusted_ip?({203, 0, 113, 5}, [],
               allowlist: @allow,
               trusted_proxies: []
             )
    end

    test "XFF from an untrusted peer is ignored for soft tier" do
      refute NetworkPolicy.soft_trusted_ip?({203, 0, 113, 5}, ["10.8.0.7"],
               allowlist: @allow,
               trusted_proxies: []
             )
    end

    test "honors XFF through a pinned proxy" do
      assert NetworkPolicy.soft_trusted_ip?({172, 16, 0, 10}, ["10.8.0.7"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )

      refute NetworkPolicy.soft_trusted_ip?({172, 16, 0, 10}, ["203.0.113.5"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end
  end

  describe "email_allowed?/1" do
    setup do
      original = Application.get_env(:matome_api, :admin_panel)

      Application.put_env(:matome_api, :admin_panel,
        enabled: true,
        email_allowlist: ["Admin@Example.com", " other@x.com "]
      )

      on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)
      :ok
    end

    test "normalizes case and whitespace" do
      assert NetworkPolicy.email_allowed?("admin@example.com")
      assert NetworkPolicy.email_allowed?("OTHER@X.COM")
      refute NetworkPolicy.email_allowed?("stranger@x.com")
    end
  end

  describe "panel_enabled?/0" do
    test "reads the admin_panel enabled flag" do
      original = Application.get_env(:matome_api, :admin_panel)
      on_exit(fn -> Application.put_env(:matome_api, :admin_panel, original) end)

      Application.put_env(:matome_api, :admin_panel, enabled: true, email_allowlist: [])
      assert NetworkPolicy.panel_enabled?()

      Application.put_env(:matome_api, :admin_panel, enabled: false, email_allowlist: [])
      refute NetworkPolicy.panel_enabled?()
    end
  end

  describe "client_ip/3" do
    test "direct connection: the peer is the client" do
      assert NetworkPolicy.client_ip({203, 0, 113, 5}, [], trusted_proxies: []) ==
               {:ok, {203, 0, 113, 5}}
    end

    test "XFF from an untrusted peer is ignored" do
      assert NetworkPolicy.client_ip({203, 0, 113, 5}, ["10.8.0.7"], trusted_proxies: @proxies) ==
               {:ok, {203, 0, 113, 5}}
    end

    test "through a pinned proxy the rightmost untrusted hop is the client" do
      assert NetworkPolicy.client_ip(
               {172, 16, 0, 10},
               ["10.8.0.7, 203.0.113.5"],
               trusted_proxies: @proxies
             ) == {:ok, {203, 0, 113, 5}}
    end

    test "fails closed on an unparseable chain behind a pinned proxy" do
      assert NetworkPolicy.client_ip({172, 16, 0, 10}, ["not-an-ip"], trusted_proxies: @proxies) ==
               :error
    end
  end
end

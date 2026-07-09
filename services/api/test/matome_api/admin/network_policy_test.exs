defmodule MatomeApi.Admin.NetworkPolicyTest do
  @moduledoc """
  W3 #1871 — the /admin network gate policy: config-driven CIDR allowlist,
  X-Forwarded-For honored ONLY through a pinned trusted-proxy chain, and
  fail-closed on every ambiguous input.
  """
  use ExUnit.Case, async: true

  alias MatomeApi.Admin.NetworkPolicy

  @allow ["10.8.0.0/24", "127.0.0.1/32", "::1/128"]
  @proxies ["172.16.0.0/16"]

  describe "allowed?/3 without proxies (direct connection)" do
    test "allows an IP inside the allowlist" do
      assert NetworkPolicy.allowed?({10, 8, 0, 7}, [], allowlist: @allow, trusted_proxies: [])
      assert NetworkPolicy.allowed?({127, 0, 0, 1}, [], allowlist: @allow, trusted_proxies: [])

      assert NetworkPolicy.allowed?({0, 0, 0, 0, 0, 0, 0, 1}, [],
               allowlist: @allow,
               trusted_proxies: []
             )
    end

    test "denies an IP outside the allowlist" do
      refute NetworkPolicy.allowed?({10, 9, 0, 7}, [], allowlist: @allow, trusted_proxies: [])
      refute NetworkPolicy.allowed?({203, 0, 113, 5}, [], allowlist: @allow, trusted_proxies: [])
    end

    test "X-Forwarded-For is IGNORED when no trusted proxies are pinned" do
      refute NetworkPolicy.allowed?({203, 0, 113, 5}, ["10.8.0.7"],
               allowlist: @allow,
               trusted_proxies: []
             )
    end

    test "X-Forwarded-For is IGNORED when the peer is not a pinned proxy" do
      # Spoofed header straight from an untrusted client.
      refute NetworkPolicy.allowed?({203, 0, 113, 5}, ["10.8.0.7"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end
  end

  describe "allowed?/3 through a pinned proxy chain" do
    test "honors XFF from a pinned proxy: allowed client passes" do
      assert NetworkPolicy.allowed?({172, 16, 0, 10}, ["10.8.0.7"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end

    test "honors XFF from a pinned proxy: disallowed client is denied" do
      refute NetworkPolicy.allowed?({172, 16, 0, 10}, ["203.0.113.5"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end

    test "walks past intermediate pinned proxies to the real client" do
      # client 10.8.0.7 -> proxy 172.16.0.9 -> proxy 172.16.0.10 (peer)
      assert NetworkPolicy.allowed?({172, 16, 0, 10}, ["10.8.0.7, 172.16.0.9"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end

    test "a client-prepended fake entry cannot spoof: rightmost untrusted wins" do
      # Attacker (203.0.113.5) sent "X-Forwarded-For: 10.8.0.7"; honest pinned
      # proxy appended the attacker's real address. The rightmost untrusted
      # hop is the attacker — the forged left entry must not be believed.
      refute NetworkPolicy.allowed?({172, 16, 0, 10}, ["10.8.0.7, 203.0.113.5"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end

    test "fails closed when the peer is a pinned proxy but XFF is absent" do
      refute NetworkPolicy.allowed?({172, 16, 0, 10}, [],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end

    test "fails closed on an unparseable XFF entry" do
      refute NetworkPolicy.allowed?({172, 16, 0, 10}, ["not-an-ip"],
               allowlist: @allow,
               trusted_proxies: @proxies
             )
    end
  end

  describe "fail-closed configuration" do
    test "an EMPTY allowlist denies everyone (prod default until topology decided)" do
      refute NetworkPolicy.allowed?({127, 0, 0, 1}, [], allowlist: [], trusted_proxies: [])
    end

    test "a missing allowlist denies everyone" do
      refute NetworkPolicy.allowed?({127, 0, 0, 1}, [], trusted_proxies: [])
    end

    test "unparseable allowlist entries are dropped, not silently allow-all" do
      refute NetworkPolicy.allowed?({127, 0, 0, 1}, [],
               allowlist: ["garbage/99"],
               trusted_proxies: []
             )
    end
  end

  describe "client_ip/3 (shared client-IP resolution, W4 #1872)" do
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

  describe "cidr parsing" do
    test "bare addresses get a full-length prefix" do
      assert NetworkPolicy.allowed?({127, 0, 0, 1}, [],
               allowlist: ["127.0.0.1"],
               trusted_proxies: []
             )

      refute NetworkPolicy.allowed?({127, 0, 0, 2}, [],
               allowlist: ["127.0.0.1"],
               trusted_proxies: []
             )
    end

    test "ipv6 cidr membership" do
      assert NetworkPolicy.allowed?({0xFD00, 0, 0, 0, 0, 0, 0, 5}, [],
               allowlist: ["fd00::/8"],
               trusted_proxies: []
             )

      refute NetworkPolicy.allowed?({0x2001, 0xDB8, 0, 0, 0, 0, 0, 5}, [],
               allowlist: ["fd00::/8"],
               trusted_proxies: []
             )
    end

    test "an ipv4 allowlist never matches an ipv6 peer (and vice versa)" do
      refute NetworkPolicy.allowed?({0, 0, 0, 0, 0, 0, 0, 1}, [],
               allowlist: ["127.0.0.1/32"],
               trusted_proxies: []
             )
    end
  end
end

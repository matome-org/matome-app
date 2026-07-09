defmodule MatomeApi.Admin.NetworkPolicy do
  @moduledoc """
  Network gate policy for /admin (W3 #1871, plan p2-core-backoffice §9.1).

  Pure decision module shared by the HTTP plug
  (`MatomeApiWeb.Plugs.AdminNetworkGuard`) and the LiveView `on_mount`
  websocket re-check. Config-driven because the deploy/network topology
  (VPN? which reverse proxy?) is still UNDECIDED — see
  `services/api/docs/admin-access-control.md`. Until that decision lands,
  the policy ships FAIL-CLOSED:

  - missing/empty `allowlist` ⇒ deny everyone (the prod default);
  - unparseable allowlist/proxy entries are dropped, never widened;
  - `X-Forwarded-For` is honored ONLY when the direct peer is inside the
    pinned `trusted_proxies` CIDRs — otherwise the header is attacker
    input and is ignored;
  - through a pinned chain, the client is the RIGHTMOST entry that is not
    itself a trusted proxy (entries the client prepended are never
    believed); any unparseable hop ⇒ deny.

  Config shape (`config :matome_api, :admin_network`):

      allowlist:       ["10.8.0.0/24", "127.0.0.1/32", "::1/128"],
      trusted_proxies: ["172.16.0.0/16"]
  """

  @doc """
  Decides whether a request may reach /admin.

  `remote_ip` is the direct peer (`conn.remote_ip` / socket peer);
  `xff_values` the raw `x-forwarded-for` header values (may contain
  comma-separated lists). `opts` defaults to the `:admin_network` app env.
  """
  def allowed?(remote_ip, xff_values, opts \\ nil) do
    opts = opts || Application.get_env(:matome_api, :admin_network, [])
    allowlist = parse_cidrs(Keyword.get(opts, :allowlist, []))
    proxies = parse_cidrs(Keyword.get(opts, :trusted_proxies, []))

    case client_ip(remote_ip, xff_values, proxies) do
      {:ok, client} -> member_of_any?(allowlist, client)
      :error -> false
    end
  end

  # Resolves the effective client IP. Only when the direct peer is a pinned
  # trusted proxy does X-Forwarded-For participate; then the client is the
  # rightmost hop that is not itself a trusted proxy.
  defp client_ip(remote_ip, xff_values, proxies) do
    cond do
      proxies == [] or not member_of_any?(proxies, remote_ip) ->
        {:ok, remote_ip}

      true ->
        with {:ok, hops} <- parse_xff(xff_values) do
          case Enum.reverse(hops) |> Enum.find(&(not member_of_any?(proxies, &1))) do
            nil ->
              # Every hop is a pinned proxy — the originator is the leftmost
              # (outermost) entry, itself trusted infrastructure.
              case hops do
                [first | _] -> {:ok, first}
                [] -> :error
              end

            client ->
              {:ok, client}
          end
        end
    end
  end

  defp parse_xff(values) do
    entries =
      values
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    parsed =
      Enum.map(entries, fn entry ->
        case :inet.parse_strict_address(String.to_charlist(entry)) do
          {:ok, ip} -> ip
          _ -> :error
        end
      end)

    if parsed == [] or :error in parsed, do: :error, else: {:ok, parsed}
  end

  defp parse_cidrs(entries) when is_list(entries) do
    Enum.flat_map(entries, fn entry ->
      case parse_cidr(entry) do
        {:ok, cidr} -> [cidr]
        :error -> []
      end
    end)
  end

  defp parse_cidrs(_), do: []

  defp parse_cidr(entry) when is_binary(entry) do
    {addr, prefix} =
      case String.split(entry, "/", parts: 2) do
        [addr] -> {addr, nil}
        [addr, prefix] -> {addr, prefix}
      end

    with {:ok, ip} <- :inet.parse_strict_address(String.to_charlist(String.trim(addr))),
         {:ok, prefix} <- normalize_prefix(prefix, bits(ip)) do
      {:ok, {ip, prefix}}
    else
      _ -> :error
    end
  end

  defp parse_cidr(_), do: :error

  defp normalize_prefix(nil, bits), do: {:ok, bits}

  defp normalize_prefix(prefix, bits) do
    case Integer.parse(String.trim(prefix)) do
      {n, ""} when n >= 0 and n <= bits -> {:ok, n}
      _ -> :error
    end
  end

  defp member_of_any?(cidrs, ip), do: Enum.any?(cidrs, &member?(&1, ip))

  defp member?({net, prefix}, ip) do
    with true <- tuple_size(net) == tuple_size(ip),
         bits = bits(ip),
         {:ok, net_int} <- ip_to_int(net),
         {:ok, ip_int} <- ip_to_int(ip) do
      shift = bits - prefix
      Bitwise.bsr(net_int, shift) == Bitwise.bsr(ip_int, shift)
    else
      _ -> false
    end
  end

  defp bits(ip) when tuple_size(ip) == 4, do: 32
  defp bits(ip) when tuple_size(ip) == 8, do: 128

  defp ip_to_int({a, b, c, d})
       when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 do
    <<n::32>> = <<a, b, c, d>>
    {:ok, n}
  end

  defp ip_to_int({a, b, c, d, e, f, g, h})
       when a in 0..65_535 and b in 0..65_535 and c in 0..65_535 and d in 0..65_535 and
              e in 0..65_535 and f in 0..65_535 and g in 0..65_535 and h in 0..65_535 do
    <<n::128>> = <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
    {:ok, n}
  end

  defp ip_to_int(_), do: :error
end

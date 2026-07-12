defmodule MatomeApi.Admin.NetworkPolicy do
  @moduledoc """
  Network + identity policy helpers for /admin.

  - **Panel kill switch** — `panel_enabled?/0` (env `ADMIN_PANEL_ENABLED`).
  - **Email allowlist** — `email_allowed?/1` (env `ADMIN_EMAIL_ALLOWLIST`).
  - **Soft IP allowlist** — `soft_trusted_ip?/2` tiers rate limits only;
    empty list means every IP is "trusted" for rate-limit purposes. The
    panel is reachable from any IP when enabled (corporate laptop / no VPN).
  - **Client IP resolution** — X-Forwarded-For honored only through pinned
    `trusted_proxies` (unchanged).

  Config shape (`config :matome_api, :admin_network`):

      allowlist:       ["10.8.0.0/24"],   # soft IP tier (optional)
      trusted_proxies: ["172.16.0.0/16"]
  """

  @doc "True when the /admin panel is enabled for this runtime."
  def panel_enabled? do
    Application.get_env(:matome_api, :admin_panel, [])
    |> Keyword.get(:enabled, false)
  end

  @doc "Normalized email allowlist from app env."
  def email_allowlist do
    Application.get_env(:matome_api, :admin_panel, [])
    |> Keyword.get(:email_allowlist, [])
    |> Enum.map(&normalize_email/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc "True when `email` is on `ADMIN_EMAIL_ALLOWLIST`."
  def email_allowed?(email) when is_binary(email) do
    normalize_email(email) in email_allowlist()
  end

  def email_allowed?(_), do: false

  @doc """
  Soft IP tier: empty allowlist ⇒ every resolvable client is trusted
  (normal rate limits). Non-empty ⇒ only listed CIDRs get the normal tier;
  everyone else still reaches /admin but under stricter rate limits.
  """
  def soft_trusted_ip?(remote_ip, xff_values, opts \\ nil) do
    opts = opts || Application.get_env(:matome_api, :admin_network, [])
    allowlist = parse_cidrs(Keyword.get(opts, :allowlist, []))
    proxies = parse_cidrs(Keyword.get(opts, :trusted_proxies, []))

    case resolve_client(remote_ip, xff_values, proxies) do
      {:ok, _client} when allowlist == [] -> true
      {:ok, client} -> member_of_any?(allowlist, client)
      :error -> false
    end
  end

  @doc """
  Resolves the effective client IP for a request. Returns `{:ok, ip_tuple}`
  or `:error` (unparseable chain behind a pinned proxy).
  """
  def client_ip(remote_ip, xff_values, opts \\ nil) do
    opts = opts || Application.get_env(:matome_api, :admin_network, [])
    proxies = parse_cidrs(Keyword.get(opts, :trusted_proxies, []))
    resolve_client(remote_ip, xff_values, proxies)
  end

  defp normalize_email(email) when is_binary(email), do: email |> String.trim() |> String.downcase()
  defp normalize_email(_), do: ""

  defp resolve_client(remote_ip, xff_values, proxies) do
    cond do
      proxies == [] or not member_of_any?(proxies, remote_ip) ->
        {:ok, remote_ip}

      true ->
        with {:ok, hops} <- parse_xff(xff_values) do
          case Enum.reverse(hops) |> Enum.find(&(not member_of_any?(proxies, &1))) do
            nil ->
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

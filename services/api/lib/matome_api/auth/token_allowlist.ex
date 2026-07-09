defmodule MatomeApi.Auth.TokenAllowlist do
  @moduledoc """
  Per-request session allowlist for access tokens (W5 #1873).

  An access token carries a `sid` claim — the jti of the refresh_tokens row
  its session was minted from (`MatomeApi.Auth.issue_tokens/2`). `check/1`
  answers whether that session is still live, in this lookup order:

    1. **ETS cache** (`:matome_token_allowlist`, owned by
       `MatomeApi.Auth.TokenAllowlist.Cache`) — entries expire after
       `cache_ttl_ms` (default 30s), which is the **bounded-staleness
       guarantee**: a node that misses an invalidation broadcast accepts a
       revoked token for at most one TTL.
    2. **Database** — `refresh_tokens` by `jti`. Row absent → `:unknown`
       (hard allowlist: not present means not allowed). `revoked_at` set →
       `:revoked`. Otherwise `:active`, cached.

  **Fail-closed:** any lookup failure (DB down, bad query) returns
  `{:denied, :unavailable}` — the caller must reject the request, never
  bypass the check. Failures are never cached.

  Enforcement itself lives in `MatomeApi.Auth.verify_access_token/1` behind
  the `mode` flag (`:off` default / `:shadow` / `:enforce`). Full contract:
  `services/api/docs/token-revocation.md`.
  """

  require Logger

  import Ecto.Query

  alias MatomeApi.Auth.RefreshToken
  alias MatomeApi.Repo

  @table :matome_token_allowlist
  @topic "token_allowlist"
  @default_ttl_ms 30_000

  @type denial :: :revoked | :unknown | :missing_binding | :unavailable
  @type result :: :allowed | {:denied, denial()}

  def table, do: @table
  def topic, do: @topic

  @doc "Enforcement mode: `:off` (default, dark), `:shadow`, or `:enforce`."
  def mode, do: config(:mode, :off)

  @doc "Cache entry TTL — the staleness bound for missed invalidations."
  def cache_ttl_ms, do: config(:cache_ttl_ms, @default_ttl_ms)

  @doc """
  Checks a session jti against the allowlist. See the moduledoc for the
  lookup order and failure semantics.
  """
  @spec check(String.t() | nil) :: result()
  def check(nil), do: {:denied, :missing_binding}

  def check(jti) when is_binary(jti) do
    if cache_enabled?() do
      case cache_get(jti) do
        {:ok, status} -> to_result(status)
        :miss -> check_db_and_cache(jti)
      end
    else
      # Revert path: no cache reads or writes — every check goes to the DB.
      case db_status(jti) do
        {:ok, status} -> to_result(status)
        :unavailable -> {:denied, :unavailable}
      end
    end
  end

  @doc """
  Busts the cache entry for a jti on every node: deletes locally right away
  (so this node is consistent immediately) and broadcasts so peer caches
  drop theirs. Call whenever a session's `revoked_at` transitions.
  """
  def invalidate(jti) when is_binary(jti) do
    safe_ets(fn -> :ets.delete(@table, jti) end)
    Phoenix.PubSub.broadcast(MatomeApi.PubSub, @topic, {:token_allowlist_invalidate, jti})
    :ok
  end

  def invalidate(nil), do: :ok

  @doc "Clears the whole cache (test isolation / operational escape hatch)."
  def reset do
    safe_ets(fn -> :ets.delete_all_objects(@table) end)
    :ok
  end

  defp check_db_and_cache(jti) do
    case db_status(jti) do
      {:ok, status} ->
        cache_put(jti, status)
        to_result(status)

      :unavailable ->
        # Never cached: the next request retries the DB.
        {:denied, :unavailable}
    end
  end

  defp to_result(:active), do: :allowed
  defp to_result(:revoked), do: {:denied, :revoked}
  defp to_result(:unknown), do: {:denied, :unknown}

  # -- database ---------------------------------------------------------------

  defp db_status(jti) do
    lookup = config(:lookup, nil) || (&default_lookup/1)
    {:ok, lookup.(jti)}
  rescue
    exception ->
      Logger.error(
        "token_allowlist lookup failed (fail-closed, request will be denied): " <>
          Exception.message(exception)
      )

      :unavailable
  end

  @doc false
  def default_lookup(jti) do
    RefreshToken
    |> where([t], t.jti == ^jti)
    |> select([t], {t.id, t.revoked_at})
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> :unknown
      {_id, nil} -> :active
      {_id, %DateTime{}} -> :revoked
    end
  end

  # -- cache ------------------------------------------------------------------

  defp cache_enabled?, do: config(:cache, true)

  defp cache_get(jti) do
    case safe_ets(fn -> :ets.lookup(@table, jti) end) do
      [{^jti, status, cached_at_ms}] ->
        if now_ms() - cached_at_ms < cache_ttl_ms(), do: {:ok, status}, else: :miss

      _ ->
        :miss
    end
  end

  defp cache_put(jti, status) do
    safe_ets(fn -> :ets.insert(@table, {jti, status, now_ms()}) end)
  end

  # The cache is an optimization layer: if the table is missing (Cache owner
  # restarting), degrade to the DB path rather than crashing the request.
  # Fail-closed is preserved — the DB (or its failure) still decides.
  defp safe_ets(fun) do
    fun.()
  rescue
    ArgumentError -> :unavailable
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp config(key, default) do
    :matome_api
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end

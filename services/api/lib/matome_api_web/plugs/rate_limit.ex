defmodule MatomeApiWeb.Plugs.RateLimit do
  @moduledoc """
  Applies one or more independent rate-limit/lockout checks to a request,
  backed by `MatomeApi.RateLimiter`.

  Options:

    * `:scope` — an atom namespacing this plug's keys (e.g. `:auth`,
      `:keybundle_get`) so counts never leak across unrelated routes.
    * `:checks` — a list of `{key_strategy, opts}` pairs. `key_strategy` is
      one of:
        * `:ip` — `conn.remote_ip`
        * `:user` — `conn.assigns.current_user.id` (skipped if absent)
        * `{:param, "name"}` — a case-insensitive request param, e.g. the
          login `email` (skipped if blank/missing)
      `opts` accepts `:limit`, `:window_ms`, and optional `:lockout_ms`
      (passed straight to `MatomeApi.RateLimiter.check/4`).

  If ANY check trips, the request is rejected with `429` and halted —
  the caller stays locked out for that check's `lockout_ms` regardless of
  which other checks would have passed.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias MatomeApi.RateLimiter

  def init(opts), do: opts

  def call(conn, opts) do
    scope = Keyword.fetch!(opts, :scope)
    checks = Keyword.fetch!(opts, :checks)

    if Enum.any?(checks, &tripped?(conn, scope, &1)) do
      conn
      |> put_status(:too_many_requests)
      |> json(%{error: "rate_limited"})
      |> halt()
    else
      conn
    end
  end

  defp tripped?(conn, scope, {strategy, check_opts}) do
    case build_key(conn, scope, strategy) do
      nil ->
        false

      key ->
        limit = Keyword.fetch!(check_opts, :limit)
        window_ms = Keyword.fetch!(check_opts, :window_ms)
        lockout_ms = Keyword.get(check_opts, :lockout_ms, window_ms)

        RateLimiter.check(key, limit, window_ms, lockout_ms) == {:error, :locked}
    end
  end

  defp build_key(conn, scope, :ip), do: {scope, :ip, ip_string(conn)}

  defp build_key(conn, scope, :user) do
    case conn.assigns[:current_user] do
      %{id: id} -> {scope, :user, id}
      _ -> nil
    end
  end

  defp build_key(conn, scope, {:param, name}) do
    case conn.params[name] do
      value when is_binary(value) and value != "" ->
        {scope, :param, name, String.downcase(value)}

      _ ->
        nil
    end
  end

  defp ip_string(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end

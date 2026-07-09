defmodule MatomeApi.Auth.TokenAllowlistTest do
  # async: false — these tests mutate the (global) allowlist ETS cache and the
  # TokenAllowlist application config; parallel runs would race on both.
  use MatomeApi.DataCase, async: false

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.Auth.{RefreshToken, TokenAllowlist}
  alias MatomeApi.Repo

  @password "correct horse battery staple"

  setup do
    TokenAllowlist.reset()
    :ok
  end

  describe "check/1 database semantics" do
    test "an active session jti is allowed" do
      %{jti: jti} = session_row()
      assert TokenAllowlist.check(jti) == :allowed
    end

    test "a revoked session jti is denied" do
      %{jti: jti} = session_row()
      revoke_in_db(jti)
      assert TokenAllowlist.check(jti) == {:denied, :revoked}
    end

    test "a jti with no session row is denied (hard allowlist)" do
      assert TokenAllowlist.check(Ecto.UUID.generate()) == {:denied, :unknown}
    end

    test "a token without a session binding is denied" do
      assert TokenAllowlist.check(nil) == {:denied, :missing_binding}
    end
  end

  describe "ETS cache" do
    test "a cache hit skips the database until invalidated" do
      %{jti: jti} = session_row()

      # Prime the cache with the active status.
      assert TokenAllowlist.check(jti) == :allowed

      # Revoke behind the cache's back: the cached :active entry keeps
      # answering until it is invalidated or its TTL lapses.
      revoke_in_db(jti)
      assert TokenAllowlist.check(jti) == :allowed

      # Invalidation busts the entry; the next check re-reads the DB.
      TokenAllowlist.invalidate(jti)
      assert TokenAllowlist.check(jti) == {:denied, :revoked}
    end

    test "a stale cache entry (past TTL) is re-read from the database" do
      %{jti: jti} = session_row()
      assert TokenAllowlist.check(jti) == :allowed
      revoke_in_db(jti)

      # Backdate the cached entry beyond the TTL — the staleness bound.
      ttl = TokenAllowlist.cache_ttl_ms()
      [{^jti, status, cached_at}] = :ets.lookup(TokenAllowlist.table(), jti)
      :ets.insert(TokenAllowlist.table(), {jti, status, cached_at - ttl - 1})

      assert TokenAllowlist.check(jti) == {:denied, :revoked}
    end

    test "with the cache disabled (revert path) every check hits the database" do
      put_config(cache: false)
      %{jti: jti} = session_row()

      assert TokenAllowlist.check(jti) == :allowed

      # No invalidation broadcast needed: denial is immediate.
      revoke_in_db(jti)
      assert TokenAllowlist.check(jti) == {:denied, :revoked}
    end

    test "a PubSub invalidation broadcast busts the entry on this node" do
      %{jti: jti} = session_row()
      assert TokenAllowlist.check(jti) == :allowed
      revoke_in_db(jti)

      Phoenix.PubSub.broadcast(
        MatomeApi.PubSub,
        TokenAllowlist.topic(),
        {:token_allowlist_invalidate, jti}
      )

      # The Cache GenServer processes the broadcast; synchronize on its
      # mailbox before asserting.
      _ = :sys.get_state(TokenAllowlist.Cache)

      assert TokenAllowlist.check(jti) == {:denied, :revoked}
    end
  end

  describe "fail-closed" do
    test "a lookup failure denies rather than bypasses, and is never cached" do
      %{jti: jti} = session_row()

      put_config(lookup: fn _jti -> raise DBConnection.ConnectionError, "allowlist db down" end)
      assert TokenAllowlist.check(jti) == {:denied, :unavailable}

      # The failure result must not be cached: once the DB is back, the same
      # jti resolves normally.
      restore_config()
      assert TokenAllowlist.check(jti) == :allowed
    end
  end

  defp session_row do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    {:ok, %{user: user}} = Auth.register_user(%{"email" => email, "password" => @password})

    Repo.one!(from(t in RefreshToken, where: t.user_id == ^user.id, limit: 1))
  end

  defp revoke_in_db(jti) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {1, _} =
      Repo.update_all(from(t in RefreshToken, where: t.jti == ^jti), set: [revoked_at: now])
  end

  defp put_config(overrides) do
    original = Application.get_env(:matome_api, TokenAllowlist, [])
    Application.put_env(:matome_api, TokenAllowlist, Keyword.merge(original, overrides))
    on_exit(fn -> Application.put_env(:matome_api, TokenAllowlist, original) end)
    original
  end

  defp restore_config do
    original =
      Application.get_env(:matome_api, TokenAllowlist, [])
      |> Keyword.delete(:lookup)

    Application.put_env(:matome_api, TokenAllowlist, original)
  end
end

defmodule MatomeApi.Auth.TokenAllowlistBenchTest do
  @moduledoc """
  Micro-benchmark for the per-request revocation check (W5 #1873).

  Measures the ETS-hit path of `TokenAllowlist.check/1` — the steady-state
  cost added to EVERY authenticated request once enforcement is on. The
  budget (docs/token-revocation.md §latency): p99 < 1ms, expected order
  single-digit microseconds. Deliberately dependency-free (`:timer.tc`
  sampling), per the no-heavy-benchmark-deps constraint.
  """

  # async: false — shares the global allowlist ETS cache.
  use MatomeApi.DataCase, async: false

  import Ecto.Query

  alias MatomeApi.Auth
  alias MatomeApi.Auth.{RefreshToken, TokenAllowlist}
  alias MatomeApi.Repo

  @warmup 1_000
  @iterations 10_000
  @p99_budget_us 1_000

  test "p99 of the ETS-hit check stays within the 1ms budget" do
    TokenAllowlist.reset()

    email = "bench-#{System.unique_integer([:positive])}@example.com"

    {:ok, %{user: user}} =
      Auth.register_user(%{"email" => email, "password" => "correct horse battery staple"})

    jti = Repo.one!(from(t in RefreshToken, where: t.user_id == ^user.id, select: t.jti))

    # Prime the cache — the first check pays the DB read; every subsequent
    # one is the ETS-hit path under measurement.
    assert TokenAllowlist.check(jti) == :allowed

    for _ <- 1..@warmup, do: TokenAllowlist.check(jti)

    timings =
      for _ <- 1..@iterations do
        {us, :allowed} = :timer.tc(fn -> TokenAllowlist.check(jti) end)
        us
      end

    sorted = Enum.sort(timings)
    p50 = Enum.at(sorted, div(@iterations, 2))
    p99 = Enum.at(sorted, round(@iterations * 0.99) - 1)

    IO.puts(
      "\ntoken_allowlist ETS-hit check: p50=#{p50}µs p99=#{p99}µs " <>
        "(#{@iterations} iterations, budget p99<#{@p99_budget_us}µs)"
    )

    assert p99 < @p99_budget_us,
           "allowlist ETS-hit p99 #{p99}µs exceeds the #{@p99_budget_us}µs budget"
  end
end

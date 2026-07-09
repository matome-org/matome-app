defmodule MatomeApi.Admin.TOTPTest do
  @moduledoc """
  W3 #1871 — RFC-6238 conformance for the admin TOTP wrapper.

  The vectors are Appendix B of RFC 6238 (SHA-1, ASCII secret
  "12345678901234567890"). The RFC lists 8-digit codes; a 6-digit code is
  the same dynamically-truncated value mod 10^6, so the expected strings
  below are the canonical vectors' last six digits.
  """
  use ExUnit.Case, async: true

  alias MatomeApi.Admin.TOTP

  @rfc_secret "12345678901234567890"

  # {unix_time, 8-digit RFC vector -> 6-digit code}
  @vectors [
    {59, "287082"},
    {1_111_111_109, "081804"},
    {1_111_111_111, "050471"},
    {1_234_567_890, "005924"},
    {2_000_000_000, "279037"},
    {20_000_000_000, "353130"}
  ]

  describe "RFC 6238 Appendix B vectors" do
    test "each vector code matches at its reference time" do
      for {time, code} <- @vectors do
        assert {:ok, timestep} = TOTP.match_timestep(@rfc_secret, code, time),
               "vector at T=#{time} did not match"

        assert timestep == div(time, 30)
      end
    end

    test "a wrong code never matches" do
      assert :error = TOTP.match_timestep(@rfc_secret, "000000", 59)
    end
  end

  describe "clock-skew window (±1 timestep)" do
    # T=1111111109 is inside timestep 37037036 (window 1111111080..1111111109).
    @time 1_111_111_109
    @code "081804"

    test "accepts the code one timestep late" do
      assert {:ok, _} = TOTP.match_timestep(@rfc_secret, @code, @time + 30)
    end

    test "accepts the code one timestep early" do
      assert {:ok, _} = TOTP.match_timestep(@rfc_secret, @code, @time - 30)
    end

    test "rejects the code two timesteps away" do
      assert :error = TOTP.match_timestep(@rfc_secret, @code, @time + 60)
      assert :error = TOTP.match_timestep(@rfc_secret, @code, @time - 60)
    end
  end

  describe "input hygiene" do
    test "rejects malformed codes without raising" do
      for bad <- ["", "12345", "1234567", "abcdef", "28 7082", nil] do
        assert :error = TOTP.match_timestep(@rfc_secret, bad, 59)
      end
    end

    test "trims surrounding whitespace from user input" do
      assert {:ok, _} = TOTP.match_timestep(@rfc_secret, " 287082 ", 59)
    end
  end

  test "generate_secret/0 produces distinct 20-byte secrets" do
    a = TOTP.generate_secret()
    b = TOTP.generate_secret()

    assert byte_size(a) == 20
    assert a != b
  end
end

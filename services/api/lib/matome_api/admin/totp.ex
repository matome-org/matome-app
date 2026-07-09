defmodule MatomeApi.Admin.TOTP do
  @moduledoc """
  RFC-6238 TOTP verification for the /admin MFA gate (W3 #1871).

  Thin wrapper over `NimbleTOTP` with two policy decisions baked in:

  - **Clock skew**: a code is accepted for the current timestep or one step
    either side (±30s) — enough for phone/server drift without widening the
    brute-force surface meaningfully.
  - **Timestep reporting**: verification returns WHICH timestep matched, so
    the caller (`MatomeApi.Admin.verify_totp/3`) can enforce one-time use by
    persisting a high-water mark and rejecting replays (RFC 6238 §5.2).

  Comparison is constant-time (`Plug.Crypto.secure_compare/2`).
  """

  @period 30
  @skew 1

  @doc "Generates a new random shared secret (20 bytes, per RFC 4226 §4)."
  def generate_secret, do: NimbleTOTP.secret()

  @doc """
  Finds the timestep (within ±#{@skew} of `now`) whose code equals `code`.

  Returns `{:ok, timestep}` on a match or `:error`. Trims surrounding
  whitespace; any non-6-digit input is rejected without raising.
  """
  def match_timestep(secret, code, now \\ System.os_time(:second))

  def match_timestep(secret, code, now) when is_binary(secret) and is_binary(code) do
    code = String.trim(code)

    if Regex.match?(~r/^\d{6}$/, code) do
      current = div(now, @period)

      Enum.find_value(-@skew..@skew, :error, fn offset ->
        timestep = current + offset
        expected = NimbleTOTP.verification_code(secret, time: timestep * @period)

        if Plug.Crypto.secure_compare(expected, code), do: {:ok, timestep}
      end)
    else
      :error
    end
  end

  def match_timestep(_secret, _code, _now), do: :error

  @doc """
  The `otpauth://` provisioning URI for authenticator apps.
  """
  def otpauth_uri(secret, account_email) do
    NimbleTOTP.otpauth_uri("matome-admin:#{account_email}", secret, issuer: "matome")
  end
end

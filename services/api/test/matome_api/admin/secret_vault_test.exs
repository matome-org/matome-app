defmodule MatomeApi.Admin.SecretVaultTest do
  @moduledoc """
  W3 #1871 — the at-rest encryption for TOTP shared secrets. AES-256-GCM via
  `:crypto`; key from application config (dev/test fallback key, prod fails
  closed at boot via runtime.exs).
  """
  use ExUnit.Case, async: false

  alias MatomeApi.Admin.SecretVault

  test "round-trips a plaintext" do
    assert {:ok, "s3kr3t-totp-seed"} =
             SecretVault.encrypt("s3kr3t-totp-seed") |> SecretVault.decrypt()
  end

  test "ciphertexts are non-deterministic (fresh IV per encryption)" do
    assert SecretVault.encrypt("same") != SecretVault.encrypt("same")
  end

  test "rejects a tampered ciphertext (GCM tag check)" do
    <<head::binary-size(29), byte, rest::binary>> = SecretVault.encrypt("s3kr3t")
    tampered = <<head::binary, Bitwise.bxor(byte, 1), rest::binary>>

    assert :error = SecretVault.decrypt(tampered)
  end

  test "rejects garbage input" do
    assert :error = SecretVault.decrypt("not a vault blob")
    assert :error = SecretVault.decrypt(<<99, 0, 1, 2>>)
  end

  test "fails closed when no key is configured" do
    original = Application.get_env(:matome_api, SecretVault)
    on_exit(fn -> Application.put_env(:matome_api, SecretVault, original) end)

    Application.delete_env(:matome_api, SecretVault)

    assert_raise RuntimeError, ~r/ADMIN_SECRET_VAULT_KEY/, fn ->
      SecretVault.encrypt("anything")
    end
  end

  test "fails closed when the key is not 32 bytes" do
    original = Application.get_env(:matome_api, SecretVault)
    on_exit(fn -> Application.put_env(:matome_api, SecretVault, original) end)

    Application.put_env(:matome_api, SecretVault, key: Base.encode64("short"))

    assert_raise RuntimeError, ~r/32/, fn ->
      SecretVault.encrypt("anything")
    end
  end
end

defmodule MatomeApi.Admin.SecretVault do
  @moduledoc """
  At-rest encryption for admin MFA secrets (W3 #1871, plan p2-core-backoffice
  §9.1) — AES-256-GCM via `:crypto`, deliberately dependency-free.

  Blob layout: `<<version::8, iv::96-bits, tag::128-bits, ciphertext>>`. A
  fresh random IV per encryption keeps ciphertexts non-deterministic; the GCM
  tag (bound to a fixed AAD naming this vault) authenticates, so any
  tampering — including bit flips in iv/tag/ciphertext — decrypts to
  `:error`, never to silently-wrong plaintext.

  Key sourcing is fail-closed: `ADMIN_SECRET_VAULT_KEY` (base64 of exactly 32
  bytes) via application config. dev/test pin a fallback key in config;
  `config/runtime.exs` raises at boot in prod when the variable is unset.
  """

  @aad "matome.admin.secret_vault.v1"
  @version 1

  @doc "Encrypts `plaintext`, returning an opaque versioned blob."
  def encrypt(plaintext) when is_binary(plaintext) do
    key = key!()
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)

    <<@version, iv::binary, tag::binary, ciphertext::binary>>
  end

  @doc "Decrypts a blob produced by `encrypt/1`. Returns `{:ok, plaintext}` or `:error`."
  def decrypt(<<@version, iv::binary-size(12), tag::binary-size(16), ciphertext::binary>>) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key!(), iv, ciphertext, @aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      _ -> :error
    end
  end

  def decrypt(_other), do: :error

  defp key! do
    encoded =
      Application.get_env(:matome_api, __MODULE__, [])[:key] ||
        raise "admin secret vault key is not configured — set ADMIN_SECRET_VAULT_KEY " <>
                "(base64 of 32 random bytes; generate with `openssl rand -base64 32`)"

    case Base.decode64(encoded) do
      {:ok, <<key::binary-size(32)>>} ->
        key

      _ ->
        raise "admin secret vault key must be base64 of exactly 32 bytes " <>
                "(generate with `openssl rand -base64 32`)"
    end
  end
end

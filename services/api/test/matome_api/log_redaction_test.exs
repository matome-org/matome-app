defmodule MatomeApi.LogRedactionTest do
  use ExUnit.Case, async: true

  test "Phoenix filters auth, content, path, and presign parameter values" do
    filters = Application.fetch_env!(:phoenix, :filter_parameters)

    for key <- ~w(
          code otp otp_code access_token refresh_token reset_token authorization
          auth secret client_secret api_key body content notes transcript summary
          local_path file_path path storage_url presigned_url x-amz-credential
          x-amz-signature x-amz-security-token
        ) do
      assert key in filters, "Phoenix filter_parameters must include #{key}"
    end
  end

  test "free-form log redaction removes secrets, content, paths, and signed credentials" do
    raw =
      ~s(Bearer bearer-secret refresh_token=refresh-secret code=123456 ) <>
        ~s(body="private words" path=/home/alice/private/audio.wav ) <>
        ~s(url=https://s3.test/object?X-Amz-Credential=credential&X-Amz-Signature=signature)

    safe = MatomeApi.LogRedaction.redact(raw)

    for secret <-
          ~w(bearer-secret refresh-secret 123456 private alice audio.wav credential signature) do
      refute safe =~ secret
    end

    assert safe =~ "[REDACTED]"
    refute function_exported?(MatomeApi.LogRedaction, :read_body, 2)
  end
end

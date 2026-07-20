defmodule MatomeApi.LogRedaction do
  @moduledoc """
  Redacts already-materialized log text. It never reads request bodies.

  Phoenix parameter filtering remains the primary structured-request guard;
  this module is the common fallback for exceptions and third-party messages.
  """

  @sensitive_keys ~w(
    password code otp otp_code token ticket access_token refresh_token reset_token
    authorization auth secret client_secret api_key body content notes transcript summary
    local_path file_path path storage_url presigned_url x-amz-credential x-amz-signature
    x-amz-security-token awsaccesskeyid
  )

  @key_pattern @sensitive_keys |> Enum.map_join("|", &Regex.escape/1)
  @field_regex Regex.compile!(
                 "(?i)([\"']?(?:" <>
                   @key_pattern <>
                   ")[\"']?\\s*(?:=|:)\\s*)(?:\"[^\"]*\"|'[^']*'|[^&,;\\s}\\]]+)"
               )
  @bearer_regex ~r/\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i
  @local_path_regex ~r/(?:file:\/\/)?(?:\/(?:home|Users|tmp)\/[^\s"'&]+|[A-Za-z]:\\[^\s"'&]+)/

  @doc "Redacts secrets, content values, local paths, and presigned credentials."
  def redact(message) when is_binary(message) do
    message
    |> then(&Regex.replace(@bearer_regex, &1, "Bearer [REDACTED]"))
    |> then(&Regex.replace(@field_regex, &1, "\\1[REDACTED]"))
    |> then(&Regex.replace(@local_path_regex, &1, "[REDACTED_PATH]"))
  end

  def redact(message), do: message |> inspect() |> redact()
end

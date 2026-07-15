defmodule MatomeApi.Storage.UploadPolicy do
  @moduledoc "Upload mode selection and S3-compatible media/provider bounds."

  alias MatomeApi.SystemConfig

  @provider_max_bytes 5 * 1024 * 1024 * 1024 * 1024
  @provider_max_parts 10_000

  @defaults [
    single_max_bytes: 25 * 1024 * 1024,
    multipart_part_bytes: 16 * 1024 * 1024,
    max_bytes: 2 * 1024 * 1024 * 1024,
    multipart_ttl_seconds: 24 * 60 * 60,
    media_max_bytes: %{
      "audio" => 2 * 1024 * 1024 * 1024,
      "image" => 50 * 1024 * 1024,
      "document" => 500 * 1024 * 1024,
      "video" => 2 * 1024 * 1024 * 1024
    }
  ]

  def single_max_bytes, do: config(:single_max_bytes)
  def multipart_part_bytes, do: config(:multipart_part_bytes)
  def max_bytes, do: config(:max_bytes)
  def multipart_ttl_seconds, do: config(:multipart_ttl_seconds)
  def provider_max_bytes, do: @provider_max_bytes

  def validate_size(_media_type, bytes)
      when not is_integer(bytes) or bytes <= 0,
      do: {:error, :invalid_content_length}

  def validate_size(_media_type, bytes) when bytes > @provider_max_bytes,
    do: {:error, :provider_limit_exceeded}

  def validate_size(media_type, bytes) do
    media_max = config(:media_max_bytes) |> Map.get(to_string(media_type))
    upload_policy = system_upload_policy()

    cond do
      is_nil(media_max) ->
        {:error, :unsupported_media_type}

      bytes > upload_policy["max_bytes"] ->
        {:error, :upload_too_large}

      bytes > media_max ->
        {:error, :media_too_large}

      part_count(bytes, upload_policy["multipart_part_bytes"]) > @provider_max_parts ->
        {:error, :provider_limit_exceeded}

      true ->
        :ok
    end
  end

  def mode_for(_media_type, bytes) do
    if bytes <= single_max_bytes(), do: :single, else: :multipart
  end

  def part_count(bytes) when is_integer(bytes) and bytes > 0 do
    part_count(bytes, multipart_part_bytes())
  end

  def part_byte_size(bytes, part_number)
      when is_integer(bytes) and bytes > 0 and is_integer(part_number) and part_number > 0 do
    part_bytes = multipart_part_bytes()
    count = part_count(bytes, part_bytes)

    if part_number <= count do
      min(part_bytes, bytes - (part_number - 1) * part_bytes)
    else
      {:error, :invalid_part_number}
    end
  end

  def part_byte_size(_bytes, _part_number), do: {:error, :invalid_part_number}

  defp part_count(bytes, part_bytes), do: div(bytes + part_bytes - 1, part_bytes)

  defp system_upload_policy, do: SystemConfig.desired()["uploads"]

  defp config(key) do
    if key in [:single_max_bytes, :multipart_part_bytes, :max_bytes] do
      system_upload_policy()[to_string(key)]
    else
      Application.get_env(:matome_api, __MODULE__, [])
      |> Keyword.get(key, Keyword.fetch!(@defaults, key))
    end
  end
end

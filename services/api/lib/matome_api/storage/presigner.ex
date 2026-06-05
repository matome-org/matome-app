defmodule MatomeApi.Storage.Presigner do
  @moduledoc """
  Issues S3-compatible presigned URLs for the Supabase Storage media bucket.

  Core owns the Storage credentials; clients receive only method-scoped URLs for
  the server-generated recording object key.
  """

  @algorithm "AWS4-HMAC-SHA256"
  @service "s3"
  @unsigned_payload "UNSIGNED-PAYLOAD"

  def presign_upload(storage_key, opts \\ []) do
    presign(:put, storage_key, Keyword.put_new(opts, :expires_in, upload_expires_in()))
  end

  def presign_download(storage_key, opts \\ []) do
    presign(:get, storage_key, Keyword.put_new(opts, :expires_in, download_expires_in()))
  end

  defp presign(method, storage_key, opts)
       when method in [:put, :get] and is_binary(storage_key) do
    expires_in = opts[:expires_in]
    now = Keyword.get(opts, :now, DateTime.utc_now())
    config = storage_config()
    endpoint = URI.parse(config.endpoint)
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date = Calendar.strftime(now, "%Y%m%d")
    scope = Enum.join([date, config.region, @service, "aws4_request"], "/")
    credential = "#{config.access_key_id}/#{scope}"
    host = host_header(endpoint)
    canonical_uri = canonical_uri(endpoint.path, config.bucket, storage_key)

    params = %{
      "X-Amz-Algorithm" => @algorithm,
      "X-Amz-Credential" => credential,
      "X-Amz-Date" => amz_date,
      "X-Amz-Expires" => to_string(expires_in),
      "X-Amz-SignedHeaders" => "host"
    }

    canonical_request =
      [
        method |> Atom.to_string() |> String.upcase(),
        canonical_uri,
        canonical_query_string(params),
        "host:#{host}\n",
        "host",
        @unsigned_payload
      ]
      |> Enum.join("\n")

    string_to_sign =
      [@algorithm, amz_date, scope, canonical_request |> sha256() |> Base.encode16(case: :lower)]
      |> Enum.join("\n")

    signature = signing_key(config.secret_access_key, date, config.region) |> hmac(string_to_sign)

    query = Map.put(params, "X-Amz-Signature", Base.encode16(signature, case: :lower))

    %{
      method: method |> Atom.to_string() |> String.upcase(),
      url: URI.to_string(%{endpoint | path: canonical_uri, query: canonical_query_string(query)}),
      expires_in: expires_in,
      storage_key: storage_key
    }
  end

  defp storage_config do
    config = Application.get_env(:matome_api, __MODULE__, [])

    %{
      endpoint: fetch_config(config, :endpoint),
      access_key_id: fetch_config(config, :access_key_id),
      secret_access_key: fetch_config(config, :secret_access_key),
      region: Keyword.get(config, :region, "local"),
      bucket: Keyword.get(config, :bucket, "media")
    }
  end

  defp fetch_config(config, key) do
    Keyword.fetch!(config, key)
  end

  defp upload_expires_in do
    Application.get_env(:matome_api, __MODULE__, []) |> Keyword.get(:upload_expires_in, 900)
  end

  defp download_expires_in do
    Application.get_env(:matome_api, __MODULE__, []) |> Keyword.get(:download_expires_in, 300)
  end

  defp canonical_uri(endpoint_path, bucket, storage_key) do
    [endpoint_path, bucket, storage_key]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.flat_map(&String.split(&1, "/", trim: true))
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> then(&("/" <> Enum.join(&1, "/")))
  end

  defp canonical_query_string(params) do
    params
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join("&", fn {key, value} ->
      "#{URI.encode(key, &URI.char_unreserved?/1)}=#{URI.encode(to_string(value), &URI.char_unreserved?/1)}"
    end)
  end

  defp host_header(%URI{host: host, port: nil}), do: host
  defp host_header(%URI{scheme: "http", host: host, port: 80}), do: host
  defp host_header(%URI{scheme: "https", host: host, port: 443}), do: host
  defp host_header(%URI{host: host, port: port}), do: "#{host}:#{port}"

  defp signing_key(secret, date, region) do
    "AWS4#{secret}"
    |> hmac(date)
    |> hmac(region)
    |> hmac(@service)
    |> hmac("aws4_request")
  end

  defp sha256(value), do: :crypto.hash(:sha256, value)
  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
end

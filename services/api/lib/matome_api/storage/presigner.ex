defmodule MatomeApi.Storage.Presigner do
  @moduledoc """
  Issues S3-compatible path-style presigned URLs for the media bucket.

  Core owns the Storage credentials; clients receive only method-scoped URLs for
  the server-generated object key.
  """

  @algorithm "AWS4-HMAC-SHA256"
  @service "s3"
  @unsigned_payload "UNSIGNED-PAYLOAD"

  alias MatomeApi.Storage.UploadPolicy

  # Every server-derived object key lives under this prefix. The presigner
  # refuses to sign anything outside it, so a key that escaped owner scoping
  # (e.g. a client-supplied path) can never be turned into a usable URL.
  @owner_prefix "owners/"

  @doc "Maximum object size accepted by the configured provider contract."
  def max_upload_bytes, do: UploadPolicy.provider_max_bytes()

  @doc """
  Presign a PUT for a server-derived `owners/...` key.

  Options:
    * `:content_length` — when given, it is validated against the provider bound
      and signed so the object store rejects a body of a different size.
    * `:checksum_sha256` — optional lowercase hex SHA-256. S3 receives and
      verifies the base64 checksum and persists the hex digest as object metadata.

  Returns `{:ok, upload}` or `{:error, reason}` where reason is one of
  `:invalid_storage_key`, `:invalid_content_length`, `:too_large`.
  """
  def presign_upload(storage_key, opts \\ []) do
    with :ok <- validate_storage_key(storage_key),
         {:ok, content_length} <- validate_content_length(opts[:content_length]),
         {:ok, checksum_headers} <- checksum_headers(opts[:checksum_sha256]) do
      headers =
        checksum_headers
        |> maybe_put_header("content-length", content_length)

      opts =
        opts
        |> Keyword.put_new(:expires_in, upload_expires_in())
        |> Keyword.put(:content_length, content_length)
        |> Keyword.put(:headers, headers)

      {:ok, presign(:put, storage_key, opts)}
    end
  end

  def presign_upload_part(storage_key, upload_id, part_number, opts \\ []) do
    with :ok <- validate_storage_key(storage_key),
         :ok <- validate_upload_id(upload_id),
         :ok <- validate_part_number(part_number),
         {:ok, content_length} <- validate_content_length(opts[:content_length]),
         {:ok, checksum_headers} <- part_checksum_headers(opts[:checksum_sha256]) do
      headers = maybe_put_header(checksum_headers, "content-length", content_length)

      opts =
        opts
        |> Keyword.put_new(:expires_in, upload_expires_in())
        |> Keyword.put(:content_length, content_length)
        |> Keyword.put(:headers, headers)
        |> Keyword.put(:query, %{
          "partNumber" => part_number,
          "uploadId" => upload_id
        })

      {:ok, presign(:put, storage_key, opts)}
    end
  end

  def presign_multipart_create(storage_key, opts \\ []) do
    with :ok <- validate_storage_key(storage_key),
         {:ok, checksum_headers} <- checksum_metadata_headers(opts[:checksum_sha256]) do
      headers = Map.put(checksum_headers, "x-amz-checksum-algorithm", "SHA256")

      {:ok,
       presign(:post, storage_key,
         expires_in: upload_expires_in(),
         query: %{"uploads" => ""},
         headers: headers,
         server: true
       )}
    end
  end

  def presign_list_parts(storage_key, upload_id) do
    with :ok <- validate_storage_key(storage_key),
         :ok <- validate_upload_id(upload_id) do
      {:ok,
       presign(:get, storage_key,
         expires_in: download_expires_in(),
         query: %{"uploadId" => upload_id},
         server: true
       )}
    end
  end

  def presign_complete_multipart(storage_key, upload_id) do
    with :ok <- validate_storage_key(storage_key),
         :ok <- validate_upload_id(upload_id) do
      {:ok,
       presign(:post, storage_key,
         expires_in: upload_expires_in(),
         query: %{"uploadId" => upload_id},
         server: true
       )}
    end
  end

  def presign_abort_multipart(storage_key, upload_id) do
    with :ok <- validate_storage_key(storage_key),
         :ok <- validate_upload_id(upload_id) do
      {:ok,
       presign(:delete, storage_key,
         expires_in: download_expires_in(),
         query: %{"uploadId" => upload_id},
         server: true
       )}
    end
  end

  def presign_head(storage_key) do
    with :ok <- validate_storage_key(storage_key) do
      {:ok,
       presign(:head, storage_key,
         expires_in: download_expires_in(),
         headers: %{"x-amz-checksum-mode" => "ENABLED"},
         server: true
       )}
    end
  end

  def presign_download(storage_key, opts \\ []) do
    with :ok <- validate_storage_key(storage_key) do
      {:ok, presign(:get, storage_key, Keyword.put_new(opts, :expires_in, download_expires_in()))}
    end
  end

  def presign_delete(storage_key, opts \\ []) do
    with :ok <- validate_storage_key(storage_key) do
      {:ok,
       presign(:delete, storage_key, Keyword.put_new(opts, :expires_in, download_expires_in()))}
    end
  end

  defp validate_storage_key(key) when is_binary(key) do
    if String.starts_with?(key, @owner_prefix) and not String.contains?(key, "..") do
      :ok
    else
      {:error, :invalid_storage_key}
    end
  end

  defp validate_storage_key(_key), do: {:error, :invalid_storage_key}

  defp validate_content_length(nil), do: {:ok, nil}

  defp validate_content_length(bytes) when is_integer(bytes) and bytes > 0 do
    if bytes > UploadPolicy.provider_max_bytes(), do: {:error, :too_large}, else: {:ok, bytes}
  end

  defp validate_content_length(_bytes), do: {:error, :invalid_content_length}

  defp validate_upload_id(value) when is_binary(value) and byte_size(value) in 1..1024, do: :ok
  defp validate_upload_id(_value), do: {:error, :invalid_upload_id}

  defp validate_part_number(value) when is_integer(value) and value in 1..10_000, do: :ok
  defp validate_part_number(_value), do: {:error, :invalid_part_number}

  defp checksum_headers(nil), do: {:ok, %{}}

  defp checksum_headers(checksum) do
    with {:ok, metadata} <- checksum_metadata_headers(checksum),
         {:ok, decoded} <- Base.decode16(checksum, case: :lower) do
      {:ok, Map.put(metadata, "x-amz-checksum-sha256", Base.encode64(decoded))}
    else
      _ -> {:error, :invalid_checksum}
    end
  end

  defp part_checksum_headers(checksum) when is_binary(checksum) do
    with {:ok, decoded} <- Base.decode16(checksum, case: :lower),
         true <- byte_size(decoded) == 32 do
      {:ok, %{"x-amz-checksum-sha256" => Base.encode64(decoded)}}
    else
      _ -> {:error, :invalid_checksum}
    end
  end

  defp part_checksum_headers(_checksum), do: {:error, :invalid_checksum}

  defp checksum_metadata_headers(nil), do: {:ok, %{}}

  defp checksum_metadata_headers(checksum)
       when is_binary(checksum) and byte_size(checksum) == 64 do
    if Regex.match?(~r/^[0-9a-f]{64}$/, checksum) do
      {:ok, %{"x-amz-meta-sha256" => checksum}}
    else
      {:error, :invalid_checksum}
    end
  end

  defp checksum_metadata_headers(_checksum), do: {:error, :invalid_checksum}

  defp maybe_put_header(headers, _key, nil), do: headers
  defp maybe_put_header(headers, key, value), do: Map.put(headers, key, to_string(value))

  defp presign(method, storage_key, opts)
       when method in [:put, :get, :post, :delete, :head] and is_binary(storage_key) do
    expires_in = opts[:expires_in]
    content_length = opts[:content_length]
    now = Keyword.get(opts, :now, DateTime.utc_now()) |> DateTime.truncate(:second)
    config = storage_config()
    endpoint = URI.parse(if(opts[:server], do: config.server_endpoint, else: config.endpoint))
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date = Calendar.strftime(now, "%Y%m%d")
    scope = Enum.join([date, config.region, @service, "aws4_request"], "/")
    credential = "#{config.access_key_id}/#{scope}"
    host = host_header(endpoint)
    canonical_uri = canonical_uri(endpoint.path, config.bucket, storage_key)
    headers = Keyword.get(opts, :headers, %{})
    {signed_headers, canonical_headers} = headers_for(host, headers)

    params =
      Keyword.get(opts, :query, %{})
      |> Map.merge(%{
        "X-Amz-Algorithm" => @algorithm,
        "X-Amz-Credential" => credential,
        "X-Amz-Date" => amz_date,
        "X-Amz-Expires" => to_string(expires_in),
        "X-Amz-SignedHeaders" => signed_headers
      })

    canonical_request =
      [
        method |> Atom.to_string() |> String.upcase(),
        canonical_uri,
        canonical_query_string(params),
        canonical_headers,
        signed_headers,
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
      expires_at: DateTime.add(now, expires_in, :second),
      storage_key: storage_key,
      content_length: content_length,
      max_bytes: UploadPolicy.provider_max_bytes(),
      headers: headers
    }
  end

  defp headers_for(host, headers) do
    headers =
      headers
      |> Map.new(fn {key, value} ->
        {key |> to_string() |> String.downcase(), canonical_header_value(value)}
      end)
      |> Map.put("host", host)
      |> Enum.sort_by(fn {key, _value} -> key end)

    signed_headers = Enum.map_join(headers, ";", fn {key, _value} -> key end)
    canonical_headers = Enum.map_join(headers, "", fn {key, value} -> "#{key}:#{value}\n" end)
    {signed_headers, canonical_headers}
  end

  defp canonical_header_value(value),
    do: value |> to_string() |> String.trim() |> String.replace(~r/\s+/, " ")

  defp storage_config do
    config = Application.get_env(:matome_api, __MODULE__, [])

    %{
      endpoint: fetch_config(config, :endpoint),
      server_endpoint: Keyword.get(config, :server_endpoint, fetch_config(config, :endpoint)),
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

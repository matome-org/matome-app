defmodule MatomeApi.Storage.ObjectStore do
  @moduledoc "S3-compatible object and multipart operations behind an injectable adapter."

  alias MatomeApi.Storage.Presigner

  def initiate_multipart(storage_key, opts) do
    dispatch(:initiate_multipart, [storage_key, opts], fn ->
      initiate_multipart_via_s3(storage_key, opts)
    end)
  end

  def presign_part(storage_key, upload_id, part_number, opts) do
    dispatch(:presign_part, [storage_key, upload_id, part_number, opts], fn ->
      Presigner.presign_upload_part(storage_key, upload_id, part_number, opts)
    end)
  end

  def list_parts(storage_key, upload_id) do
    dispatch(:list_parts, [storage_key, upload_id], fn ->
      list_parts_via_s3(storage_key, upload_id)
    end)
  end

  def complete_multipart(storage_key, upload_id, parts) do
    dispatch(:complete_multipart, [storage_key, upload_id, parts], fn ->
      complete_multipart_via_s3(storage_key, upload_id, parts)
    end)
  end

  def abort_multipart(storage_key, upload_id) do
    dispatch(:abort_multipart, [storage_key, upload_id], fn ->
      abort_multipart_via_s3(storage_key, upload_id)
    end)
  end

  def head_object(storage_key) do
    dispatch(:head_object, [storage_key], fn -> head_object_via_s3(storage_key) end)
  end

  def delete_object(storage_key) do
    dispatch(:delete_object, [storage_key], fn -> delete_via_s3(storage_key) end)
  end

  def get_object(storage_key) do
    dispatch(:get_object, [storage_key], fn -> get_via_s3(storage_key) end)
  end

  defp dispatch(operation, args, fallback) do
    case Application.get_env(:matome_api, __MODULE__, [])[:adapter] do
      {module, arg} -> apply(module, operation, args ++ [arg])
      module when is_atom(module) and not is_nil(module) -> apply(module, operation, args)
      _ -> fallback.()
    end
  end

  defp initiate_multipart_via_s3(storage_key, opts) do
    with {:ok, request} <-
           Presigner.presign_multipart_create(storage_key,
             checksum_sha256: opts[:checksum_sha256]
           ),
         {:ok, 200, _headers, body} <- request(:post, request, ""),
         {:ok, upload_id} <- xml_text(body, "UploadId") do
      {:ok, %{upload_id: upload_id}}
    else
      {:ok, status, _headers, body} -> {:error, {:storage_create_multipart_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp list_parts_via_s3(storage_key, upload_id) do
    with {:ok, request} <- Presigner.presign_list_parts(storage_key, upload_id),
         {:ok, 200, _headers, body} <- request(:get, request),
         {:ok, parts} <- parse_parts(body) do
      {:ok, parts}
    else
      {:ok, 404, _headers, _body} -> {:error, :no_such_upload}
      {:ok, status, _headers, body} -> {:error, {:storage_list_parts_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp complete_multipart_via_s3(storage_key, upload_id, parts) do
    body = complete_xml(parts)

    with {:ok, request} <- Presigner.presign_complete_multipart(storage_key, upload_id),
         {:ok, status, _headers, _body} when status in 200..299 <- request(:post, request, body) do
      :ok
    else
      {:ok, 404, _headers, _body} -> {:error, :no_such_upload}
      {:ok, status, _headers, body} -> {:error, {:storage_complete_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp abort_multipart_via_s3(storage_key, upload_id) do
    with {:ok, request} <- Presigner.presign_abort_multipart(storage_key, upload_id),
         {:ok, status, _headers, _body} when status in 200..299 or status == 404 <-
           request(:delete, request) do
      :ok
    else
      {:ok, status, _headers, body} -> {:error, {:storage_abort_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp head_object_via_s3(storage_key) do
    with {:ok, request} <- Presigner.presign_head(storage_key),
         {:ok, 200, headers, _body} <- request(:head, request),
         {:ok, byte_size} <- parse_integer_header(headers, "content-length") do
      {:ok,
       %{
         byte_size: byte_size,
         etag: headers |> header("etag") |> normalize_etag(),
         checksum_sha256: checksum_header(headers)
       }}
    else
      {:ok, 404, _headers, _body} -> {:error, :not_found}
      {:ok, status, _headers, body} -> {:error, {:storage_head_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_via_s3(storage_key) do
    with {:ok, delete} <- Presigner.presign_delete(storage_key, server: true),
         {:ok, status, _headers, _body} when status in 200..299 or status == 404 <-
           request(:delete, delete) do
      :ok
    else
      {:ok, status, _headers, body} -> {:error, {:storage_delete_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_via_s3(storage_key) do
    with {:ok, download} <- Presigner.presign_download(storage_key, server: true),
         {:ok, 200, _headers, body} <- request(:get, download) do
      {:ok, IO.iodata_to_binary(body)}
    else
      {:ok, 404, _headers, _body} -> {:error, :not_found}
      {:ok, status, _headers, body} -> {:error, {:storage_get_failed, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request(method, signed_request, body \\ nil) do
    url = String.to_charlist(signed_request.url)

    headers =
      signed_request.headers
      |> Enum.map(fn {key, value} -> {String.to_charlist(key), String.to_charlist(value)} end)

    request =
      if method == :post do
        {url, headers, ~c"application/xml", body || ""}
      else
        {url, headers}
      end

    case http_client().request(method, request, [], []) do
      {:ok, {{_, status, _}, response_headers, response_body}} ->
        {:ok, status, response_headers, response_body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_parts(body) do
    parts =
      ~r/<Part>(.*?)<\/Part>/s
      |> Regex.scan(to_string(body), capture: :all_but_first)
      |> Enum.map(fn [part_xml] ->
        with {:ok, part_number} <- xml_integer(part_xml, "PartNumber"),
             {:ok, byte_size} <- xml_integer(part_xml, "Size"),
             {:ok, etag} <- xml_text(part_xml, "ETag"),
             {:ok, checksum} <- xml_text(part_xml, "ChecksumSHA256"),
             {:ok, checksum_sha256} <- decode_checksum(checksum) do
          {:ok,
           %{
             part_number: part_number,
             byte_size: byte_size,
             etag: normalize_etag(etag),
             checksum_sha256: checksum_sha256
           }}
        end
      end)

    case Enum.find(parts, &match?({:error, _reason}, &1)) do
      nil -> {:ok, Enum.map(parts, fn {:ok, part} -> part end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp complete_xml(parts) do
    encoded_parts =
      Enum.map_join(parts, "", fn part ->
        checksum = part.checksum_sha256 |> Base.decode16!(case: :lower) |> Base.encode64()

        "<Part><PartNumber>#{part.part_number}</PartNumber>" <>
          "<ETag>#{xml_escape(part.etag)}</ETag>" <>
          "<ChecksumSHA256>#{checksum}</ChecksumSHA256></Part>"
      end)

    "<CompleteMultipartUpload>#{encoded_parts}</CompleteMultipartUpload>"
  end

  defp xml_text(body, tag) do
    case Regex.run(~r/<#{tag}>(.*?)<\/#{tag}>/s, to_string(body), capture: :all_but_first) do
      [value] -> {:ok, xml_unescape(value)}
      _ -> {:error, :invalid_storage_response}
    end
  end

  defp xml_integer(body, tag) do
    with {:ok, value} <- xml_text(body, tag),
         {integer, ""} <- Integer.parse(value) do
      {:ok, integer}
    else
      _ -> {:error, :invalid_storage_response}
    end
  end

  defp decode_checksum(value) do
    case Base.decode64(value) do
      {:ok, <<_::256>> = checksum} -> {:ok, Base.encode16(checksum, case: :lower)}
      _ -> {:error, :invalid_storage_response}
    end
  end

  defp parse_integer_header(headers, key) do
    case header(headers, key) do
      nil ->
        {:error, :invalid_storage_response}

      value ->
        case Integer.parse(value) do
          {integer, ""} -> {:ok, integer}
          _ -> {:error, :invalid_storage_response}
        end
    end
  end

  defp checksum_header(headers) do
    case header(headers, "x-amz-checksum-sha256") do
      nil ->
        header(headers, "x-amz-meta-sha256")

      checksum ->
        case decode_checksum(checksum) do
          {:ok, value} -> value
          {:error, _reason} -> header(headers, "x-amz-meta-sha256")
        end
    end
  end

  defp header(headers, key) do
    key = String.downcase(key)

    Enum.find_value(headers, fn {header_key, value} ->
      if header_key |> to_string() |> String.downcase() == key, do: to_string(value)
    end)
  end

  defp normalize_etag(nil), do: nil
  defp normalize_etag(etag), do: String.trim(etag, "\"")

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp xml_unescape(value) do
    value
    |> String.replace("&#34;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&amp;", "&")
  end

  defp http_client do
    Application.get_env(:matome_api, __MODULE__, [])[:http_client] || :httpc
  end
end

defmodule MatomeApi.Storage.ObjectStore.Noop do
  def delete_object(_storage_key), do: :ok
  def get_object(_storage_key), do: {:error, :not_found}
  def head_object(_storage_key), do: {:error, :not_found}
  def initiate_multipart(_storage_key, _opts), do: {:error, :storage_unavailable}

  def presign_part(_storage_key, _upload_id, _part_number, _opts),
    do: {:error, :storage_unavailable}

  def list_parts(_storage_key, _upload_id), do: {:error, :storage_unavailable}
  def complete_multipart(_storage_key, _upload_id, _parts), do: {:error, :storage_unavailable}
  def abort_multipart(_storage_key, _upload_id), do: :ok
end

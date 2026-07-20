defmodule MatomeApi.Content.DocumentOpenPolicy do
  @moduledoc "Server-owned classification and response policy for stored documents."

  @active_extensions ~w(html htm xhtml svg xml xsl xslt)
  @active_mime_types ~w(
    application/xhtml+xml
    application/xml
    image/svg+xml
    text/html
    text/xml
  )
  @unsafe_extensions ~w(
    action apk app bat bash cgi cmd com command cpl deb desktop dll dmg exe fish gadget
    hta inf ins isp jar js jse ksh lnk mjs msc msi msp mst php pif pl ps1 ps1xml py rb reg
    rpm run scf scr sct sh sys url vb vbe vbs vhd vhdx vmdk workflow wsf wsh xpi zsh
  )
  @unsafe_mime_types ~w(
    application/javascript
    application/ecmascript
    application/hta
    application/wasm
    application/x-bat
    application/x-dosexec
    application/x-executable
    application/x-httpd-php
    application/x-msdownload
    application/x-msdos-program
    application/x-ms-shortcut
    application/x-sh
    application/x-shellscript
    text/javascript
    text/ecmascript
    text/x-python
    text/x-script.python
    text/x-shellscript
  )
  @office_mime_types %{
    "doc" => ~w(application/msword),
    "docx" => ~w(application/vnd.openxmlformats-officedocument.wordprocessingml.document),
    "xls" => ~w(application/vnd.ms-excel),
    "xlsx" => ~w(application/vnd.openxmlformats-officedocument.spreadsheetml.sheet),
    "ppt" => ~w(application/vnd.ms-powerpoint),
    "pptx" => ~w(application/vnd.openxmlformats-officedocument.presentationml.presentation),
    "rtf" => ~w(application/rtf text/rtf),
    "odt" => ~w(application/vnd.oasis.opendocument.text),
    "ods" => ~w(application/vnd.oasis.opendocument.spreadsheet),
    "odp" => ~w(application/vnd.oasis.opendocument.presentation)
  }

  @policies ~w(external system_app attachment_only download_only blocked)
  @cfb_magic <<0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1>>

  def policies, do: @policies

  def metadata(filename, content_type) do
    filename = sanitize_filename(filename)
    extension = extension(filename)
    content_type = normalize_content_type(content_type)
    policy = classify(extension, content_type)

    if policy == "blocked" do
      {:error, :unsafe_file_type}
    else
      {:ok,
       %{
         filename: filename,
         original_extension: extension,
         content_type: content_type,
         open_policy: policy
       }}
    end
  end

  def current_policy(metadata) do
    filename = Map.get(metadata, :filename) || Map.get(metadata, "filename")
    content_type = Map.get(metadata, :content_type) || Map.get(metadata, "content_type")
    filename |> sanitize_filename() |> extension() |> classify(content_type)
  end

  def classify(extension, content_type) do
    extension = extension && extension |> String.trim() |> String.trim(".") |> String.downcase()
    content_type = normalize_content_type(content_type)

    cond do
      extension in @unsafe_extensions or content_type in @unsafe_mime_types -> "blocked"
      extension in @active_extensions or content_type in @active_mime_types -> "attachment_only"
      extension == "pdf" and content_type == "application/pdf" -> "external"
      extension in ~w(txt text log) and content_type == "text/plain" -> "external"
      content_type in Map.get(@office_mime_types, extension, []) -> "system_app"
      true -> "download_only"
    end
  end

  def sanitize_filename(nil), do: "download"

  def sanitize_filename(filename) when is_binary(filename) do
    filename
    |> String.split(~r{[/\\]}, trim: true)
    |> List.last()
    |> case do
      nil -> "download"
      basename -> basename
    end
    |> String.replace(~r/[\x00-\x1F\x7F<>:"|?*]/u, "_")
    |> String.trim()
    |> String.trim_trailing(".")
    |> String.trim_trailing()
    |> case do
      "" -> "download"
      sanitized -> String.slice(sanitized, 0, 255)
    end
  end

  def sanitize_filename(_filename), do: "download"

  def extension(nil), do: nil

  def extension(filename) do
    filename = filename |> String.trim() |> String.trim_trailing(".") |> String.trim_trailing()

    candidate = Path.extname(filename)

    candidate =
      if candidate == "" and String.starts_with?(filename, "."), do: filename, else: candidate

    case candidate do
      "." <> extension when extension != "" ->
        extension = String.downcase(extension)
        if Regex.match?(~r/^[a-z0-9][a-z0-9+_-]{0,31}$/, extension), do: extension

      _ ->
        nil
    end
  end

  def normalize_content_type(content_type) when is_binary(content_type) do
    normalized =
      content_type
      |> String.split(";", parts: 2)
      |> hd()
      |> String.trim()
      |> String.downcase()

    if Regex.match?(
         ~r/^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}\/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$/,
         normalized
       ) do
      normalized
    else
      "application/octet-stream"
    end
  end

  def normalize_content_type(_content_type), do: "application/octet-stream"

  def verify_signature(%{open_policy: policy}, _prefix)
      when policy not in ["external", "system_app"],
      do: policy

  def verify_signature(metadata, prefix) when is_binary(prefix) and byte_size(prefix) <= 8192 do
    extension = Map.get(metadata, :original_extension) || Map.get(metadata, "original_extension")

    case extension do
      "pdf" ->
        if String.starts_with?(prefix, "%PDF-"), do: "external", else: "download_only"

      extension when extension in ~w(doc xls ppt) ->
        if String.starts_with?(prefix, @cfb_magic), do: "system_app", else: "download_only"

      extension when extension in ~w(docx xlsx pptx odt ods odp) ->
        if zip_prefix?(prefix), do: "system_app", else: "download_only"

      "rtf" ->
        if String.starts_with?(prefix, "{\\rtf"), do: "system_app", else: "download_only"

      extension when extension in ~w(txt text log) ->
        text_signature_policy(prefix)

      _ ->
        "download_only"
    end
  end

  def verify_signature(_metadata, _prefix), do: "download_only"

  def safe_metadata(metadata) do
    filename = Map.get(metadata, :filename) || Map.get(metadata, "filename")
    content_type = Map.get(metadata, :content_type) || Map.get(metadata, "content_type")
    persisted_policy = Map.get(metadata, :open_policy) || Map.get(metadata, "open_policy")

    with {:ok, current} <- metadata(filename, content_type) do
      effective_policy = restrict_policy(current.open_policy, persisted_policy)

      if effective_policy == "blocked" do
        {:error, :unsafe_file_type}
      else
        {:ok, %{current | open_policy: effective_policy}}
      end
    end
  end

  def download_descriptor(metadata) do
    with {:ok, safe} <- safe_metadata(metadata) do
      {action, disposition, response_content_type, warning} =
        case safe.open_policy do
          "external" ->
            {"open", "inline", safe.content_type, nil}

          "system_app" ->
            {"open_in_app", "attachment", safe.content_type, nil}

          "attachment_only" ->
            {"download", "attachment", "application/octet-stream", "active_content"}

          _ ->
            {"download", "attachment", "application/octet-stream", nil}
        end

      {:ok,
       %{
         action: action,
         filename: safe.filename,
         original_extension: safe.original_extension,
         content_type: response_content_type,
         content_disposition: content_disposition(disposition, safe.filename),
         cache_control: "private, no-store, max-age=0",
         open_policy: safe.open_policy,
         warning: warning
       }}
    end
  end

  defp restrict_policy(_current, "blocked"), do: "blocked"
  defp restrict_policy("download_only", _persisted), do: "download_only"
  defp restrict_policy(_current, "download_only"), do: "download_only"
  defp restrict_policy("attachment_only", _persisted), do: "attachment_only"
  defp restrict_policy(_current, "attachment_only"), do: "attachment_only"
  defp restrict_policy(policy, policy), do: policy
  defp restrict_policy(_current, _persisted), do: "download_only"

  defp zip_prefix?(<<"PK", 3, 4, _rest::binary>>), do: true
  defp zip_prefix?(<<"PK", 5, 6, _rest::binary>>), do: true
  defp zip_prefix?(<<"PK", 7, 8, _rest::binary>>), do: true
  defp zip_prefix?(_prefix), do: false

  defp text_signature_policy(prefix) do
    cond do
      not String.valid?(prefix) or String.contains?(prefix, <<0>>) -> "download_only"
      binary_text?(prefix) -> "download_only"
      active_markup?(prefix) -> "attachment_only"
      true -> "external"
    end
  end

  defp binary_text?(prefix) do
    controls =
      prefix
      |> :binary.bin_to_list()
      |> Enum.count(&(&1 < 32 and &1 not in [9, 10, 12, 13]))

    controls > 0
  end

  defp active_markup?(prefix) do
    Regex.match?(~r/<(?:!doctype\s+html|html\b|script\b|svg\b|\?xml\b)/i, prefix)
  end

  defp content_disposition(disposition, filename) do
    fallback = String.replace(filename, ~r/[^\x20-\x7E]/u, "_")
    encoded = URI.encode(filename, &URI.char_unreserved?/1)
    ~s(#{disposition}; filename="#{fallback}"; filename*=UTF-8''#{encoded})
  end
end

defmodule MatomeApi.AIEngine do
  @moduledoc """
  Core-side client for the external AI Engine contract.

  The real engine lives outside this monorepo; this module only dispatches jobs
  and authenticates the local callback contract used by the stub and production
  service.
  """

  alias MatomeApi.Content.Recording
  alias MatomeApi.Storage.Presigner

  def token do
    config() |> Keyword.get(:token, "")
  end

  def dispatch(%Recording{} = recording, attempt) do
    job_id = job_id(recording.id, attempt)
    body = Jason.encode!(payload(recording, attempt, job_id))
    headers = [{~c"content-type", ~c"application/json"} | auth_header()]

    case :httpc.request(:post, {endpoint(), headers, ~c"application/json", body}, [],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _headers, response_body}} when status in 200..299 ->
        {:ok, decode_response(response_body)}

      {:ok, {{_, status, _}, _headers, response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp payload(recording, attempt, job_id) do
    download = Presigner.presign_download(recording.storage_key)
    expires_at = DateTime.utc_now() |> DateTime.add(download.expires_in, :second)

    %{
      job_id: job_id,
      recording_id: recording.id,
      media_type: recording.media_type || "audio",
      storage_key: recording.storage_key,
      media: %{
        method: "GET",
        url: download.url,
        expires_at: DateTime.to_iso8601(expires_at)
      },
      callback: %{
        method: "POST",
        url: callback_url(job_id)
      },
      metadata: %{
        owner_id: recording.owner_id,
        workspace_id: recording.workspace_id,
        attempt: attempt
      }
    }
  end

  defp endpoint do
    config() |> Keyword.fetch!(:endpoint) |> String.to_charlist()
  end

  defp callback_url(job_id) do
    encoded = URI.encode(job_id, &URI.char_unreserved?/1)
    base = config() |> Keyword.fetch!(:callback_base_url) |> String.trim_trailing("/")
    "#{base}/internal/jobs/#{encoded}/result"
  end

  defp job_id(recording_id, attempt), do: "recording:#{recording_id}:attempt:#{attempt}"

  defp auth_header do
    case token() do
      "" -> []
      nil -> []
      token -> [{~c"authorization", ~c"Bearer #{token}"}]
    end
  end

  defp decode_response(""), do: %{}
  defp decode_response(body), do: Jason.decode!(body)

  defp config, do: Application.fetch_env!(:matome_api, __MODULE__)
end

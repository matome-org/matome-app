defmodule MatomeApi.Storage.ObjectStore do
  @moduledoc "Deletes Core-owned storage objects."

  alias MatomeApi.Storage.Presigner

  def delete_object(storage_key) do
    case Application.get_env(:matome_api, __MODULE__, [])[:adapter] do
      {module, arg} -> module.delete_object(storage_key, arg)
      module when is_atom(module) and not is_nil(module) -> module.delete_object(storage_key)
      _ -> delete_via_s3(storage_key)
    end
  end

  defp delete_via_s3(storage_key) do
    with {:ok, delete} <- Presigner.presign_delete(storage_key) do
      url = String.to_charlist(delete.url)
      headers = []
      request = {url, headers}

      case http_client().request(:delete, request, [], []) do
        {:ok, {{_, status, _}, _headers, _body}} when status in 200..299 ->
          :ok

        {:ok, {{_, 404, _}, _headers, _body}} ->
          :ok

        {:ok, {{_, status, _}, _headers, body}} ->
          {:error, {:storage_delete_failed, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp http_client do
    Application.get_env(:matome_api, __MODULE__, [])[:http_client] || :httpc
  end
end

defmodule MatomeApi.Storage.ObjectStore.Noop do
  def delete_object(_storage_key), do: :ok
end

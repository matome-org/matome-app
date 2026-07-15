defmodule MatomeApi.AIEngine.HTTPDispatchAdapter do
  @moduledoc false

  def dispatch(endpoint, token, payload, timeout_seconds) do
    body = Jason.encode!(payload)
    headers = [{~c"content-type", ~c"application/json"}]

    headers =
      if token == "", do: headers, else: [{~c"authorization", ~c"Bearer #{token}"} | headers]

    case :httpc.request(
           :post,
           {String.to_charlist(endpoint), headers, ~c"application/json", body},
           [
             timeout: :timer.seconds(timeout_seconds),
             connect_timeout: min(:timer.seconds(timeout_seconds), :timer.seconds(10))
           ],
           []
         ) do
      {:ok, {{_, status, _}, _headers, response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, {{_, status, _}, _headers, response_body}} ->
        {:error, {:http_error, status, to_string(response_body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

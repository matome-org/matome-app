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
      {:ok, {{_, 202, _}, _headers, response_body}} ->
        decode_response(response_body, 4096)

      {:ok, {{_, status, _}, _headers, _response_body}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def capabilities(jobs_endpoint, token, timeout_seconds) do
    endpoint =
      jobs_endpoint
      |> URI.parse()
      |> Map.merge(%{path: "/v1/capabilities", query: nil, fragment: nil})
      |> URI.to_string()

    headers = if token == "", do: [], else: [{~c"authorization", ~c"Bearer #{token}"}]

    case :httpc.request(
           :get,
           {String.to_charlist(endpoint), headers},
           [
             timeout: :timer.seconds(timeout_seconds),
             connect_timeout: min(:timer.seconds(timeout_seconds), :timer.seconds(10))
           ],
           []
         ) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        decode_response(response_body, 65_536)

      {:ok, {{_, status, _}, _headers, _response_body}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_response(response_body, max_bytes) do
    body = to_string(response_body)

    if byte_size(body) <= max_bytes,
      do: Jason.decode(body),
      else: {:error, :response_too_large}
  end
end

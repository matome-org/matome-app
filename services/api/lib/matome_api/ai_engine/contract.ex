defmodule MatomeApi.AIEngine.Contract do
  @moduledoc false

  @input_kinds ~w(audio image document text)
  @typed_outputs %{
    "audio" => ~w(transcript summary title),
    "image" => ~w(ocr_text description summary title),
    "document" => ~w(extracted_text summary title),
    "text" => ~w(summary title)
  }
  @max_capabilities_bytes 65_536
  @max_callback_bytes 4_210_000
  @max_outputs_bytes 4_194_304
  @max_output_text_bytes 4_000_000

  def validate_capabilities(capabilities) when is_map(capabilities) do
    with :ok <- encoded_size(capabilities, @max_capabilities_bytes),
         true <- exact_keys?(capabilities, ~w(contract_version inputs service)),
         "1" <- capabilities["contract_version"],
         service when is_binary(service) and byte_size(service) in 1..255 <-
           capabilities["service"],
         inputs when is_map(inputs) <- capabilities["inputs"],
         true <- Map.keys(inputs) |> Enum.all?(&(&1 in @input_kinds)),
         true <- Enum.all?(inputs, fn {kind, input} -> valid_capability?(kind, input) end) do
      {:ok, capabilities}
    else
      _invalid -> {:error, :invalid_capabilities}
    end
  end

  def validate_capabilities(_capabilities), do: {:error, :invalid_capabilities}

  def validate_dispatch_ack(body, payload) when is_map(body) do
    normalized = stringify_keys(body)

    if exact_keys?(normalized, ~w(accepted contract_version job_id run_id)) and
         normalized == %{
           "accepted" => true,
           "contract_version" => "1",
           "job_id" => payload.job_id,
           "run_id" => payload.run_id
         } do
      :ok
    else
      {:error, :invalid_dispatch_ack}
    end
  end

  def validate_dispatch_ack(_body, _payload), do: {:error, :invalid_dispatch_ack}

  def normalize_callback(params, requested_outputs) when is_map(params) do
    with :ok <- encoded_size(params, @max_callback_bytes),
         true <- is_list(requested_outputs),
         {:ok, identity} <- callback_identity(params),
         {:ok, terminal} <- callback_terminal(params, identity.status, requested_outputs) do
      {:ok, Map.merge(identity, terminal)}
    else
      _invalid -> {:error, :invalid_callback}
    end
  end

  def normalize_callback(_params, _requested_outputs), do: {:error, :invalid_callback}

  defp valid_capability?(kind, input) when is_map(input) do
    allowed_outputs = Map.fetch!(@typed_outputs, kind)
    outputs = input["outputs"]

    common? =
      is_boolean(input["enabled"]) and is_list(outputs) and outputs == Enum.uniq(outputs) and
        Enum.all?(outputs, &(&1 in allowed_outputs))

    case kind do
      "text" ->
        exact_keys?(input, ~w(enabled max_characters outputs)) and common? and
          positive_integer?(input["max_characters"])

      _file ->
        content_types = input["content_types"]

        exact_keys?(input, ~w(content_types enabled max_bytes outputs)) and common? and
          positive_integer?(input["max_bytes"]) and is_list(content_types) and
          content_types != [] and content_types == Enum.uniq(content_types) and
          Enum.all?(content_types, &bounded_string?(&1, 255))
    end
  end

  defp valid_capability?(_kind, _input), do: false

  defp callback_identity(params) do
    with true <-
           exact_keys?(params, callback_keys(params["status"])),
         "1" <- params["contract_version"],
         job_id when is_binary(job_id) and byte_size(job_id) in 1..255 <- params["job_id"],
         run_id when is_binary(run_id) <- params["run_id"],
         {:ok, _uuid} <- Ecto.UUID.cast(run_id),
         item_id when is_integer(item_id) and item_id > 0 <- params["item_id"],
         revision when is_integer(revision) and revision > 0 <- params["input_revision"],
         status when status in ~w(done failed) <- params["status"] do
      {:ok,
       %{
         job_id: job_id,
         run_id: run_id,
         item_id: item_id,
         input_revision: revision,
         status: status
       }}
    else
      _invalid -> {:error, :invalid_identity}
    end
  end

  defp callback_keys("done"),
    do: ~w(contract_version input_revision item_id job_id outputs run_id status)

  defp callback_keys("failed"),
    do: ~w(contract_version error input_revision item_id job_id run_id status)

  defp callback_keys(_status), do: []

  defp callback_terminal(params, "done", requested_outputs) do
    outputs = params["outputs"]

    with true <- is_list(outputs) and length(outputs) in 1..10,
         {:ok, normalized} <- normalize_outputs(outputs),
         types = Map.keys(normalized),
         true <- MapSet.subset?(MapSet.new(types), MapSet.new(requested_outputs)),
         :ok <- encoded_size(normalized, @max_outputs_bytes) do
      state =
        if MapSet.new(types) == MapSet.new(requested_outputs), do: :succeeded, else: :partial

      {:ok, %{state: state, outputs: normalized, error: nil}}
    else
      _invalid -> {:error, :invalid_outputs}
    end
  end

  defp callback_terminal(params, "failed", _requested_outputs) do
    case params["error"] do
      %{"code" => code, "message" => message, "retryable" => retryable} = error
      when is_boolean(retryable) ->
        if exact_keys?(error, ~w(code message retryable)) and stable_code?(code) and
             bounded_string?(message, 1024) do
          {:ok,
           %{
             state: :failed,
             outputs: %{},
             error: Map.put(error, "message", MatomeApi.LogRedaction.redact(message))
           }}
        else
          {:error, :invalid_error}
        end

      _invalid ->
        {:error, :invalid_error}
    end
  end

  defp normalize_outputs(outputs) do
    Enum.reduce_while(outputs, {:ok, %{}}, fn output, {:ok, acc} ->
      with {:ok, normalized} <- normalize_output(output),
           type = normalized["type"],
           false <- Map.has_key?(acc, type) do
        {:cont, {:ok, Map.put(acc, type, normalized)}}
      else
        _invalid -> {:halt, {:error, :invalid_output}}
      end
    end)
  end

  defp normalize_output(%{"type" => "transcript", "text" => text} = output) do
    if exact_keys?(output, ~w(text type), ~w(language duration_ms)) and
         output_text?(text) and optional_language?(output["language"]) and
         optional_non_negative_integer?(output["duration_ms"]) do
      {:ok, output}
    else
      {:error, :invalid_output}
    end
  end

  defp normalize_output(%{"type" => type, "text" => text} = output)
       when type in ~w(ocr_text extracted_text) do
    if exact_keys?(output, ~w(text type), ~w(language)) and output_text?(text) and
         optional_language?(output["language"]) do
      {:ok, output}
    else
      {:error, :invalid_output}
    end
  end

  defp normalize_output(%{"type" => "description", "text" => text} = output) do
    if exact_keys?(output, ~w(text type)) and output_text?(text),
      do: {:ok, output},
      else: {:error, :invalid_output}
  end

  defp normalize_output(%{"type" => "summary", "markdown" => markdown} = output) do
    if exact_keys?(output, ~w(markdown type)) and output_text?(markdown),
      do: {:ok, output},
      else: {:error, :invalid_output}
  end

  defp normalize_output(%{"type" => "title", "text" => text} = output) do
    if exact_keys?(output, ~w(text type)) and bounded_string?(text, 255),
      do: {:ok, output},
      else: {:error, :invalid_output}
  end

  defp normalize_output(_output), do: {:error, :invalid_output}

  defp exact_keys?(map, required, optional \\ []) when is_map(map) do
    keys = Map.keys(map) |> Enum.sort()
    required = Enum.sort(required)
    allowed = Enum.sort(required ++ optional)
    Enum.all?(required, &(&1 in keys)) and Enum.all?(keys, &(&1 in allowed))
  end

  defp stringify_keys(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp encoded_size(value, limit) do
    case Jason.encode(value) do
      {:ok, encoded} when byte_size(encoded) <= limit -> :ok
      _too_large_or_invalid -> {:error, :payload_too_large}
    end
  end

  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp optional_non_negative_integer?(nil), do: true
  defp optional_non_negative_integer?(value), do: is_integer(value) and value >= 0
  defp optional_language?(nil), do: true
  defp optional_language?(value), do: bounded_string?(value, 35)
  defp output_text?(value), do: bounded_string?(value, @max_output_text_bytes)

  defp bounded_string?(value, max),
    do: is_binary(value) and byte_size(value) in 1..max

  defp stable_code?(code) when is_binary(code) and byte_size(code) in 1..100,
    do: Regex.match?(~r/^[a-z][a-z0-9_]*$/, code)

  defp stable_code?(_code), do: false
end

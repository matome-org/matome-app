defmodule MatomeApi.SystemConfig.Policy do
  @moduledoc "Strict v1 validation for the non-secret global policy document."

  @top_keys ~w(applied desired revision schema_version)
  @desired_keys ~w(ai clients queue retry uploads)
  @queue_keys ~w(lease_seconds max_concurrency paused snapshot_interval_seconds)
  @retry_keys ~w(base_delay_seconds max_attempts max_delay_seconds)
  @upload_keys ~w(max_bytes multipart_part_bytes single_max_bytes)
  @ai_keys ~w(enabled_input_kinds job_timeout_seconds)
  @client_keys ~w(minimum_wire_version poll_interval_seconds)
  @applied_keys ~w(core_applied_at core_revision)
  @input_kinds ~w(audio image document text)

  @default_desired %{
    "queue" => %{
      "paused" => false,
      "lease_seconds" => 120,
      "max_concurrency" => 2,
      "snapshot_interval_seconds" => 900
    },
    "retry" => %{
      "max_attempts" => 5,
      "base_delay_seconds" => 2,
      "max_delay_seconds" => 300
    },
    "uploads" => %{
      "single_max_bytes" => 25 * 1024 * 1024,
      "multipart_part_bytes" => 16 * 1024 * 1024,
      "max_bytes" => 2 * 1024 * 1024 * 1024
    },
    "ai" => %{
      "enabled_input_kinds" => @input_kinds,
      "job_timeout_seconds" => 1800
    },
    "clients" => %{
      "minimum_wire_version" => "1",
      "poll_interval_seconds" => 2
    }
  }

  def default_document do
    %{
      "schema_version" => 1,
      "revision" => 1,
      "desired" => @default_desired,
      "applied" => %{"core_revision" => 0, "core_applied_at" => nil}
    }
  end

  def default_desired, do: @default_desired

  def validate(document) do
    errors =
      []
      |> exact_keys(document, [], @top_keys)
      |> equal(document, ["schema_version"], 1)
      |> integer(document, ["revision"], 1, nil)
      |> exact_keys(value_at(document, ["desired"]), ["desired"], @desired_keys)
      |> exact_keys(value_at(document, ["desired", "queue"]), ["desired", "queue"], @queue_keys)
      |> exact_keys(value_at(document, ["desired", "retry"]), ["desired", "retry"], @retry_keys)
      |> exact_keys(
        value_at(document, ["desired", "uploads"]),
        ["desired", "uploads"],
        @upload_keys
      )
      |> exact_keys(value_at(document, ["desired", "ai"]), ["desired", "ai"], @ai_keys)
      |> exact_keys(
        value_at(document, ["desired", "clients"]),
        ["desired", "clients"],
        @client_keys
      )
      |> exact_keys(value_at(document, ["applied"]), ["applied"], @applied_keys)
      |> boolean(document, ["desired", "queue", "paused"])
      |> integer(document, ["desired", "queue", "lease_seconds"], 15, 3600)
      |> integer(document, ["desired", "queue", "max_concurrency"], 1, 16)
      |> integer(document, ["desired", "queue", "snapshot_interval_seconds"], 60, 86_400)
      |> integer(document, ["desired", "retry", "max_attempts"], 1, 20)
      |> integer(document, ["desired", "retry", "base_delay_seconds"], 1, 3600)
      |> integer(document, ["desired", "retry", "max_delay_seconds"], 1, 86_400)
      |> integer(document, ["desired", "uploads", "single_max_bytes"], 1, 2_147_483_648)
      |> integer(document, ["desired", "uploads", "multipart_part_bytes"], 5_242_880, 536_870_912)
      |> integer(document, ["desired", "uploads", "max_bytes"], 5_242_880, 2_147_483_648)
      |> input_kinds(document)
      |> integer(document, ["desired", "ai", "job_timeout_seconds"], 30, 86_400)
      |> wire_version(document)
      |> integer(document, ["desired", "clients", "poll_interval_seconds"], 1, 3600)
      |> integer(document, ["applied", "core_revision"], 0, nil)
      |> applied_at(document)
      |> ordered(document, ["desired", "retry", "base_delay_seconds"], [
        "desired",
        "retry",
        "max_delay_seconds"
      ])
      |> ordered(document, ["desired", "uploads", "single_max_bytes"], [
        "desired",
        "uploads",
        "max_bytes"
      ])
      |> ordered(document, ["desired", "uploads", "multipart_part_bytes"], [
        "desired",
        "uploads",
        "max_bytes"
      ])
      |> ordered(document, ["applied", "core_revision"], ["revision"])
      |> Enum.uniq()
      |> Enum.sort()

    if errors == [], do: {:ok, document}, else: {:error, errors}
  end

  defp exact_keys(errors, map, path, expected) when is_map(map) do
    actual = Map.keys(map) |> Enum.map(&to_string/1)
    unknown = actual -- expected
    missing = expected -- actual

    Enum.reduce(unknown ++ missing, errors, fn key, acc -> [path(key, path) | acc] end)
  end

  defp exact_keys(errors, _value, path, _expected), do: [path(path) | errors]

  defp equal(errors, document, path, expected) do
    if value_at(document, path) == expected, do: errors, else: [path(path) | errors]
  end

  defp boolean(errors, document, path) do
    if is_boolean(value_at(document, path)), do: errors, else: [path(path) | errors]
  end

  defp integer(errors, document, path, minimum, maximum) do
    value = value_at(document, path)

    if is_integer(value) and value >= minimum and (is_nil(maximum) or value <= maximum) do
      errors
    else
      [path(path) | errors]
    end
  end

  defp input_kinds(errors, document) do
    path = ["desired", "ai", "enabled_input_kinds"]
    value = value_at(document, path)

    if is_list(value) and Enum.uniq(value) == value and Enum.all?(value, &(&1 in @input_kinds)) do
      errors
    else
      [path(path) | errors]
    end
  end

  defp wire_version(errors, document) do
    path = ["desired", "clients", "minimum_wire_version"]

    case value_at(document, path) do
      value when is_binary(value) ->
        if Regex.match?(~r/^[1-9][0-9]*$/, value), do: errors, else: [path(path) | errors]

      _value ->
        [path(path) | errors]
    end
  end

  defp applied_at(errors, document) do
    path = ["applied", "core_applied_at"]

    case value_at(document, path) do
      nil ->
        errors

      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, _datetime, _offset} -> errors
          _error -> [path(path) | errors]
        end

      _value ->
        [path(path) | errors]
    end
  end

  defp ordered(errors, document, lower_path, upper_path) do
    lower = value_at(document, lower_path)
    upper = value_at(document, upper_path)

    if is_integer(lower) and is_integer(upper) and lower > upper do
      [path(lower_path) | errors]
    else
      errors
    end
  end

  defp value_at(value, []), do: value

  defp value_at(map, [key | rest]) when is_map(map),
    do: value_at(Map.get(map, key), rest)

  defp value_at(_value, _path), do: nil

  defp path(path) when is_list(path), do: Enum.join(path, ".")
  defp path(key, []), do: key
  defp path(key, path), do: Enum.join(path ++ [key], ".")
end

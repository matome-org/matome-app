defmodule MatomeApi.Auth.DeviceMeta do
  @moduledoc """
  Normalize client-declared device descriptors for `devices` rows.

  Allowlists enums; derives `form_factor` / `device_class` from `platform`
  when the client omits them.
  """

  @platforms ~w(android ios linux macos windows web)
  @form_factors ~w(mobile desktop web)
  @device_classes ~w(smartphone tablet laptop desktop browser unknown)

  @doc """
  Normalize a client `device` map into attrs ready for `Device.changeset/2`.

  Accepts string or atom keys. Returns string keys:
  `platform`, `form_factor`, `device_class`, `model`, `display_name`.
  """
  def normalize(params) when is_map(params) do
    platform = normalize_enum(get(params, "platform") || get(params, :platform), @platforms)
    form_factor =
      normalize_enum(get(params, "form_factor") || get(params, :form_factor), @form_factors) ||
        derive_form_factor(platform)

    device_class =
      normalize_enum(get(params, "device_class") || get(params, :device_class), @device_classes) ||
        derive_device_class(platform)

    model = blank_to_nil(get(params, "model") || get(params, :model))
    display_name = blank_to_nil(get(params, "display_name") || get(params, :display_name))

    %{
      "platform" => platform,
      "form_factor" => form_factor,
      "device_class" => device_class,
      "model" => model,
      "display_name" => display_name || model
    }
  end

  def normalize(_), do: normalize(%{})

  defp derive_form_factor("android"), do: "mobile"
  defp derive_form_factor("ios"), do: "mobile"
  defp derive_form_factor("web"), do: "web"
  defp derive_form_factor(os) when os in ~w(linux macos windows), do: "desktop"
  defp derive_form_factor(_), do: "unknown"

  defp derive_device_class("android"), do: "smartphone"
  defp derive_device_class("ios"), do: "smartphone"
  defp derive_device_class("web"), do: "browser"
  defp derive_device_class(os) when os in ~w(linux macos windows), do: "desktop"
  defp derive_device_class(_), do: "unknown"

  defp normalize_enum(nil, _allowed), do: nil

  defp normalize_enum(value, allowed) when is_binary(value) do
    trimmed = value |> String.trim() |> String.downcase()

    cond do
      trimmed == "" -> nil
      trimmed in allowed -> trimmed
      true -> "unknown"
    end
  end

  defp normalize_enum(value, allowed) when is_atom(value),
    do: normalize_enum(Atom.to_string(value), allowed)

  defp normalize_enum(_, _), do: "unknown"

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> String.slice(trimmed, 0, 255)
    end
  end

  defp blank_to_nil(value), do: blank_to_nil(to_string(value))

  defp get(map, key) when is_map(map), do: Map.get(map, key)
end

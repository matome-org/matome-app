defmodule MatomeApi.Auth.DeviceMetaTest do
  use ExUnit.Case, async: true

  alias MatomeApi.Auth.DeviceMeta

  test "derives form_factor and device_class from platform when omitted" do
    assert DeviceMeta.normalize(%{"platform" => "linux"}) == %{
             "platform" => "linux",
             "form_factor" => "desktop",
             "device_class" => "desktop",
             "model" => nil,
             "display_name" => nil
           }

    assert DeviceMeta.normalize(%{"platform" => "android"})["form_factor"] == "mobile"
    assert DeviceMeta.normalize(%{"platform" => "android"})["device_class"] == "smartphone"
    assert DeviceMeta.normalize(%{"platform" => "web"})["form_factor"] == "web"
    assert DeviceMeta.normalize(%{"platform" => "web"})["device_class"] == "browser"
  end

  test "keeps explicit enums and uses model as display_name fallback" do
    assert DeviceMeta.normalize(%{
             "platform" => "Linux",
             "form_factor" => "desktop",
             "device_class" => "laptop",
             "model" => "ThinkPad T14"
           }) == %{
             "platform" => "linux",
             "form_factor" => "desktop",
             "device_class" => "laptop",
             "model" => "ThinkPad T14",
             "display_name" => "ThinkPad T14"
           }
  end

  test "unknown platform strings normalize to unknown" do
    assert DeviceMeta.normalize(%{"platform" => "amiga"})["platform"] == "unknown"
    assert DeviceMeta.normalize(%{"platform" => "amiga"})["form_factor"] == "unknown"
  end
end

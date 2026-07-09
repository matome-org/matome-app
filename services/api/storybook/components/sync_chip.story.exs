defmodule Storybook.Components.SyncChip do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.sync_chip/1

  def variations do
    [
      %VariationGroup{
        id: :states,
        variations: [
          %Variation{id: :cloud, attributes: %{state: "cloud"}},
          %Variation{id: :syncing, attributes: %{state: "syncing"}},
          %Variation{id: :on_device, attributes: %{state: "on_device"}}
        ]
      }
    ]
  end
end

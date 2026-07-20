defmodule Storybook.Components.SpaceChip do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.space_chip/1

  def variations do
    [
      %Variation{id: :in_space, attributes: %{space: "Work"}},
      %Variation{id: :inbox, attributes: %{space: nil}}
    ]
  end
end

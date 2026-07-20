defmodule Storybook.Components.MatomeChip do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.matome_chip/1

  def variations do
    [
      %Variation{id: :filed, attributes: %{matome: "Q3 Planning"}},
      %Variation{id: :unfiled, attributes: %{matome: nil}}
    ]
  end
end

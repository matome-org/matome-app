defmodule Storybook.Composites.ContactTile do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.contact_tile/1

  def variations do
    [
      %Variation{
        id: :with_notes,
        attributes: %{name: "Ana Ribeiro", notes: "Design lead", color: "blue"}
      },
      %Variation{id: :bare, attributes: %{name: "Leo"}},
      %Variation{id: :selected, attributes: %{name: "Ken Adams", color: "green", selected: true}}
    ]
  end
end

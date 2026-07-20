defmodule Storybook.Components.Avatar do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.avatar/1

  def variations do
    [
      %VariationGroup{
        id: :sizes,
        variations: [
          %Variation{id: :sm, attributes: %{initials: "GF", size: "sm"}},
          %Variation{id: :md, attributes: %{initials: "GF", size: "md"}},
          %Variation{id: :lg, attributes: %{initials: "GF", size: "lg"}}
        ]
      },
      %Variation{id: :with_icon, attributes: %{icon: "person", size: "md"}}
    ]
  end
end

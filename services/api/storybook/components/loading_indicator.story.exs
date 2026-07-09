defmodule Storybook.Components.LoadingIndicator do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.loading_indicator/1

  def variations do
    [
      %VariationGroup{
        id: :sizes,
        variations: [
          %Variation{id: :sm, attributes: %{size: "sm"}},
          %Variation{id: :md, attributes: %{size: "md"}},
          %Variation{id: :lg, attributes: %{size: "lg"}}
        ]
      }
    ]
  end
end

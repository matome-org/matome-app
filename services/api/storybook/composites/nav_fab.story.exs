defmodule Storybook.Composites.NavFab do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.nav_fab/1

  def variations do
    [
      %Variation{id: :default, attributes: %{}},
      %Variation{id: :custom_label, attributes: %{icon: "add", label: "New matome"}}
    ]
  end
end

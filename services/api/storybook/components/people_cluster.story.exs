defmodule Storybook.Components.PeopleCluster do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.people_cluster/1

  def variations do
    [
      %Variation{id: :few, attributes: %{names: ["Ana", "Bob"]}},
      %Variation{
        id: :overflow,
        attributes: %{names: ["Ana", "Bob", "Cy", "Dan", "Eve"]}
      }
    ]
  end
end

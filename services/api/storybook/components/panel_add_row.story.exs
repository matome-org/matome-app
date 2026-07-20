defmodule Storybook.Components.PanelAddRow do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.panel_add_row/1

  def variations do
    [
      %Variation{id: :default, attributes: %{label: "Add contact"}}
    ]
  end
end

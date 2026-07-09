defmodule Storybook.Components.IconButton do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.icon_button/1

  def variations do
    [
      %Variation{id: :default, attributes: %{name: "settings", label: "Settings"}},
      %Variation{
        id: :disabled,
        attributes: %{name: "settings", label: "Settings", disabled: true}
      }
    ]
  end
end

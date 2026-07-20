defmodule Storybook.Components.PanelSection do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.panel_section/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{label: "Details"},
        slots: [
          ~s|<:action><button>Edit</button></:action>|,
          "Section body"
        ]
      }
    ]
  end
end

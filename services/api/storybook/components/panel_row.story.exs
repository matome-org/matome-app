defmodule Storybook.Components.PanelRow do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.panel_row/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{icon: "person", title: "Ana Souza", meta: "Organizer"}
      },
      %Variation{
        id: :with_trailing,
        attributes: %{title: "Item"},
        slots: [~s|<:trailing>›</:trailing>|]
      }
    ]
  end
end

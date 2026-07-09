defmodule Storybook.Components.EmptyState do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.empty_state/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{title: "No items", message: "Nothing here yet."}
      },
      %Variation{
        id: :with_icon,
        attributes: %{title: "No items", message: "Nothing here yet."},
        slots: [~s|<:icon>📭</:icon>|]
      }
    ]
  end
end

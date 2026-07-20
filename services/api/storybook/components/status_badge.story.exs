defmodule Storybook.Components.StatusBadge do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.status_badge/1

  def variations do
    [
      %VariationGroup{
        id: :tones,
        variations: [
          %Variation{id: :work, attributes: %{label: "Work", tone: "work"}},
          %Variation{id: :personal, attributes: %{label: "Personal", tone: "personal"}},
          %Variation{id: :ideas, attributes: %{label: "Ideas", tone: "ideas"}},
          %Variation{id: :default, attributes: %{label: "Default", tone: "default"}}
        ]
      }
    ]
  end
end

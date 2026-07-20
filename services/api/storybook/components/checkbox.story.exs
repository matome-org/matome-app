defmodule Storybook.Components.Checkbox do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.checkbox/1

  def variations do
    [
      %Variation{id: :unchecked, slots: ["Remember me"]},
      %Variation{id: :checked, attributes: %{checked: true}, slots: ["Remember me"]},
      %Variation{id: :disabled, attributes: %{disabled: true}, slots: ["Remember me"]}
    ]
  end
end

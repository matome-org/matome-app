defmodule Storybook.Components.TextButton do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.text_button/1

  def variations do
    [
      %Variation{id: :default, slots: ["Cancel"]},
      %Variation{id: :with_icon, attributes: %{icon: "refresh"}, slots: ["Retry"]},
      %Variation{id: :disabled, attributes: %{disabled: true}, slots: ["Cancel"]}
    ]
  end
end

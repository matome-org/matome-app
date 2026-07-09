defmodule Storybook.Components.PrimaryButton do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.primary_button/1

  def variations do
    [
      %Variation{id: :default, slots: ["Save changes"]},
      %Variation{id: :with_icon, attributes: %{icon: "add"}, slots: ["New"]},
      %Variation{id: :disabled, attributes: %{disabled: true}, slots: ["Save"]}
    ]
  end
end

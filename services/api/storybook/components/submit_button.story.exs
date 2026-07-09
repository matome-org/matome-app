defmodule Storybook.Components.SubmitButton do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.submit_button/1

  def variations do
    [
      %Variation{id: :idle, slots: ["Sign in"]},
      %Variation{id: :loading, attributes: %{loading: true}, slots: ["Sign in"]},
      %Variation{id: :disabled, attributes: %{disabled: true}, slots: ["Sign in"]}
    ]
  end
end

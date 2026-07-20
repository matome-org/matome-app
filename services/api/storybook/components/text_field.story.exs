defmodule Storybook.Components.TextField do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.text_field/1

  def variations do
    [
      %Variation{id: :default, attributes: %{label: "Email", hint: "you@example.com"}},
      %Variation{
        id: :email,
        attributes: %{label: "Email", type: "email", hint: "you@example.com", name: "email"}
      },
      %Variation{
        id: :with_value,
        attributes: %{label: "Email", value: "hi@x.com"}
      },
      %Variation{
        id: :password,
        attributes: %{label: "Password", obscure: true, value: "secret"}
      },
      %Variation{
        id: :disabled,
        attributes: %{label: "Email", value: "hi@x.com", disabled: true}
      }
    ]
  end
end

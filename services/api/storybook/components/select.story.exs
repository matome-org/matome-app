defmodule Storybook.Components.Select do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.select/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{
          label: "Role",
          options: [{"Admin", "admin"}, {"User", "user"}],
          value: "user"
        }
      },
      %Variation{
        id: :disabled,
        attributes: %{
          label: "Role",
          options: [{"Admin", "admin"}, {"User", "user"}],
          value: "user",
          disabled: true
        }
      }
    ]
  end
end

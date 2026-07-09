defmodule Storybook.Components.RoleChip do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.role_chip/1

  def variations do
    [
      %VariationGroup{
        id: :roles,
        variations: [
          %Variation{id: :organizer, attributes: %{role: "organizer"}},
          %Variation{id: :speaker, attributes: %{role: "speaker"}},
          %Variation{id: :attendee, attributes: %{role: "attendee"}}
        ]
      }
    ]
  end
end

defmodule Storybook.Composites.NavDock do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.nav_dock/1

  @dests [
    %{id: "inbox", icon: "inbox", label: "Inbox"},
    %{id: "calendar", icon: "schedule", label: "Calendar"},
    %{id: "files", icon: "folder", label: "Files"}
  ]

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{destinations: @dests, active_id: "inbox", account_name: "Leo"}
      }
    ]
  end
end

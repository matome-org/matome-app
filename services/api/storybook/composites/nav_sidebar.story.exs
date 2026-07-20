defmodule Storybook.Composites.NavSidebar do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.nav_sidebar/1

  @dests [
    %{id: "inbox", icon: "inbox", label: "Inbox"},
    %{id: "files", icon: "folder", label: "Files"},
    %{id: "people", icon: "group", label: "People"}
  ]

  def variations do
    [
      %Variation{
        id: :expanded,
        attributes: %{destinations: @dests, active_id: "files", account_name: "Ana Ribeiro"}
      },
      %Variation{
        id: :collapsed,
        attributes: %{destinations: @dests, active_id: "files", collapsed: true}
      }
    ]
  end
end

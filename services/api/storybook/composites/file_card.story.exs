defmodule Storybook.Composites.FileCard do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.file_card/1

  def template do
    """
    <div style="max-width: 260px">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :audio,
        attributes: %{
          name: "standup.m4a",
          kind: "audio",
          at: "Mon",
          size: "4.2 MB",
          duration: "03:12",
          matome: "Client X",
          space: "Marketing",
          people: ["Ana", "Ken"],
          sync: "syncing",
          selected: true
        }
      },
      %Variation{
        id: :unfiled_document,
        attributes: %{name: "memo.txt", kind: "document"}
      }
    ]
  end
end

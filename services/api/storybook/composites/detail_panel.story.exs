defmodule Storybook.Composites.DetailPanel do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.detail_panel/1

  def template do
    """
    <div style="max-width: 380px">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :filed,
        attributes: %{
          title: "Client X — weekly",
          items: [
            %{media: "audio", title: "Meeting audio", meta: "12:04", sync: "cloud"},
            %{media: "image", title: "Whiteboard", meta: nil, sync: "on_device"}
          ],
          contacts: [%{initial: "A", name: "Ana", role: "Organizer"}],
          space_name: "Marketing",
          notes: "Discussed Q3."
        }
      },
      %Variation{
        id: :inbox,
        attributes: %{title: "Loose note", items: [], contacts: []}
      }
    ]
  end
end

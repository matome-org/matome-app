defmodule Storybook.Composites.AppCard do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.app_card/1

  def imports do
    [
      {MatomeApiWeb.MatomeComposites, [meta_token: 1, place_chip: 1]},
      {MatomeApiWeb.MatomeComponents, [sync_chip: 1]}
    ]
  end

  def template do
    """
    <div style="max-width: 420px">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :matome,
        attributes: %{variant: "matome", title: "Client X — weekly", summary: "Recap"},
        slots: [
          ~s|<:meta><.meta_token icon="mic" label="2" /><.place_chip space="Marketing" /><.sync_chip state="cloud" /></:meta>|
        ]
      },
      %Variation{
        id: :calendar,
        attributes: %{
          variant: "calendar",
          title: "Team standup",
          badge: "work",
          badge_label: "Work",
          duration: "30m"
        }
      },
      %Variation{
        id: :recording_done,
        attributes: %{
          variant: "recording",
          title: "Meeting",
          state: "done",
          sync: "cloud",
          duration: "12:04"
        }
      },
      %Variation{
        id: :recording_failed,
        attributes: %{
          variant: "recording",
          title: "Meeting",
          state: "failed",
          status_label: "Failed",
          status_tone: "default"
        }
      }
    ]
  end
end

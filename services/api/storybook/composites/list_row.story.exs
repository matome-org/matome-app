defmodule Storybook.Composites.ListRow do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.list_row/1

  def imports, do: [{MatomeApiWeb.MatomeComponents, [sync_chip: 1]}]

  def variations do
    [
      %Variation{
        id: :with_footer,
        attributes: %{
          icon: "mic",
          title: "Standup audio",
          meta: "14:30 · 03:12",
          tag: "Loose"
        },
        slots: [~s|<:footer><.sync_chip state="on_device" /></:footer>|]
      },
      %Variation{
        id: :with_trailing,
        attributes: %{icon: "folder", title: "Marketing", meta: "12 items"},
        slots: [~s|<:trailing>›</:trailing>|]
      }
    ]
  end
end

defmodule Storybook.Composites.MasterDetail do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.master_detail/1

  def template do
    """
    <div style="max-width: 720px">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :with_detail,
        attributes: %{show_close: true},
        slots: [
          ~s|<:master>Master list</:master>|,
          ~s|<:detail>Detail pane</:detail>|,
          ~s|<:empty>Nothing selected</:empty>|
        ]
      },
      %Variation{
        id: :empty,
        slots: [
          ~s|<:master>Master list</:master>|,
          ~s|<:empty>Nothing selected</:empty>|
        ]
      }
    ]
  end
end

defmodule Storybook.Composites.DataTable do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.data_table/1

  def imports do
    [
      {MatomeApiWeb.MatomeComposites, [table_primary_cell: 1, table_count: 1]},
      {MatomeApiWeb.MatomeComponents, [text_button: 1]}
    ]
  end

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
        id: :selectable,
        attributes: %{
          rows: [
            %{id: "r1", title: "Weekly sync", summary: "Notes", when: "Mon"},
            %{id: "r2", title: "Design review", summary: nil, when: "Tue"}
          ],
          selectable: true,
          selected: ["r1"],
          active_id: "r2",
          sort_key: "when",
          sort_dir: "desc"
        },
        slots: [
          ~s|<:col :let={row} label="Title" sortable sort_key="title"><.table_primary_cell title={row.title} summary={row.summary} /></:col>|,
          ~s|<:col :let={row} label="When" width="when" align="center" sortable sort_key="when">{row.when}</:col>|,
          ~s|<:bulk_actions><.text_button icon="archive">Archive</.text_button></:bulk_actions>|
        ]
      },
      %Variation{
        id: :empty,
        attributes: %{rows: [], empty_title: "No sessions"},
        slots: [~s|<:col label="Title">x</:col>|]
      }
    ]
  end
end

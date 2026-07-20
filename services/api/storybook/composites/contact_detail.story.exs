defmodule Storybook.Composites.ContactDetail do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComposites.contact_detail/1

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
        id: :full,
        attributes: %{
          name: "Ana Ribeiro",
          subtitle: "Design lead · Acme",
          sync: "cloud",
          email: "ana@acme.co",
          phone: "+1 555 0100",
          company: "Acme",
          notes: "Prefers async.",
          matomes: [%{title: "Client X sync", role: "organizer", when: "Mon"}],
          spaces: ["Marketing", "Ops"],
          files: [%{name: "brief.pdf", kind: "document"}]
        }
      },
      %Variation{id: :sparse, attributes: %{name: "Leo"}}
    ]
  end
end

defmodule Storybook.Components.Icon do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.icon/1

  @names ~w(check close error add cloud folder person file settings mic image video group mail phone edit delete)

  def variations do
    [
      %VariationGroup{
        id: :glyphs,
        variations:
          for name <- @names do
            %Variation{id: String.to_atom(name), attributes: %{name: name}}
          end
      }
    ]
  end
end

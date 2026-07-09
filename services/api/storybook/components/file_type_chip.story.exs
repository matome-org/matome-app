defmodule Storybook.Components.FileTypeChip do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.file_type_chip/1

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{file_name: "notes.pdf", size_label: "2.4 MB"}
      },
      %Variation{id: :unknown_size, attributes: %{file_name: "recording.m4a"}}
    ]
  end
end

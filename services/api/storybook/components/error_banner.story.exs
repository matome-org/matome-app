defmodule Storybook.Components.ErrorBanner do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.error_banner/1

  def variations do
    [
      %Variation{id: :default, attributes: %{message: "Something went wrong."}}
    ]
  end
end

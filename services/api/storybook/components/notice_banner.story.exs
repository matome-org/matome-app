defmodule Storybook.Components.NoticeBanner do
  use PhoenixStorybook.Story, :component

  def function, do: &MatomeApiWeb.MatomeComponents.notice_banner/1

  def variations do
    [
      %Variation{id: :default, attributes: %{message: "Reset link sent."}}
    ]
  end
end

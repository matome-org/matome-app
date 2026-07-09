defmodule Storybook.Foundations.Spacing do
  use PhoenixStorybook.Story, :page

  def doc, do: "Matome spacing scale (--matome-space-* tokens)."

  @scale ~w(xxs xs sm md lg xl xxl)

  def render(assigns) do
    assigns = assign(assigns, scale: @scale)

    ~H"""
    <div style="display:flex;flex-direction:column;gap:12px;padding:8px">
      <div :for={step <- @scale} style="display:flex;align-items:center;gap:12px">
        <code style="width:120px;font-size:12px">--matome-space-{step}</code>
        <div style={"height:16px;border-radius:4px;background:var(--matome-accent);width:var(--matome-space-#{step})"}>
        </div>
      </div>
    </div>
    """
  end
end

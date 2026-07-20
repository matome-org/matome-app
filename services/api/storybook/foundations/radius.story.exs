defmodule Storybook.Foundations.Radius do
  use PhoenixStorybook.Story, :page

  def doc, do: "Matome corner-radius scale (--matome-radius-* tokens)."

  @scale ~w(sm md lg xl pill)

  def render(assigns) do
    assigns = assign(assigns, scale: @scale)

    ~H"""
    <div style="display:flex;flex-wrap:wrap;gap:20px;padding:8px">
      <div :for={step <- @scale} style="font-size:12px;text-align:center">
        <div style={"width:72px;height:72px;background:var(--matome-accent-soft);border:1px solid var(--matome-accent);border-radius:var(--matome-radius-#{step})"}>
        </div>
        <code style="display:block;margin-top:6px">--matome-radius-{step}</code>
      </div>
    </div>
    """
  end
end

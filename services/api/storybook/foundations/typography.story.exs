defmodule Storybook.Foundations.Typography do
  use PhoenixStorybook.Story, :page

  def doc, do: "Matome type scale (display / title / body / label) from the --matome-type-* tokens."

  @styles [
    {"Display", "display", "--matome-font-display",
     "The quick brown fox jumps over the lazy dog"},
    {"Title", "title", "--matome-font-display", "The quick brown fox jumps over the lazy dog"},
    {"Body", "body", "--matome-font-body", "The quick brown fox jumps over the lazy dog"},
    {"Body small", "body-small", "--matome-font-body",
     "The quick brown fox jumps over the lazy dog"},
    {"Label", "label", "--matome-font-body", "THE QUICK BROWN FOX"}
  ]

  def render(assigns) do
    assigns = assign(assigns, styles: @styles)

    ~H"""
    <div style="display:flex;flex-direction:column;gap:20px;padding:8px">
      <div :for={{name, key, font, sample} <- @styles}>
        <div style="font-size:12px;opacity:0.7;margin-bottom:4px">
          {name} · var(--matome-type-{key}-size)
        </div>
        <div style={"font-family:var(#{font});font-size:var(--matome-type-#{key}-size);font-weight:var(--matome-type-#{key}-weight);line-height:var(--matome-type-#{key}-line);letter-spacing:var(--matome-type-#{key}-tracking);color:var(--matome-text-primary)"}>
          {sample}
        </div>
      </div>
    </div>
    """
  end
end

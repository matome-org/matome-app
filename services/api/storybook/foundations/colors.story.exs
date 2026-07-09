defmodule Storybook.Foundations.Colors do
  use PhoenixStorybook.Story, :page

  def doc, do: "Matome color tokens (--matome-* CSS variables from assets/css/foundations.css)."

  @core [
    {"accent", "--matome-accent"},
    {"accent-dark", "--matome-accent-dark"},
    {"accent-soft", "--matome-accent-soft"},
    {"background", "--matome-background"},
    {"surface", "--matome-surface"},
    {"border", "--matome-border"},
    {"text-primary", "--matome-text-primary"},
    {"text-secondary", "--matome-text-secondary"},
    {"text-muted", "--matome-text-muted"},
    {"failed", "--matome-failed"}
  ]

  @badges [
    {"work", "--matome-badge-work"},
    {"personal", "--matome-badge-personal"},
    {"ideas", "--matome-badge-ideas"},
    {"default", "--matome-badge-default"}
  ]

  @spaces [
    {"gold", "--matome-space-gold"},
    {"green", "--matome-space-green"},
    {"blue", "--matome-space-blue"},
    {"orange", "--matome-space-orange"},
    {"rose", "--matome-space-rose"},
    {"purple", "--matome-space-purple"},
    {"teal", "--matome-space-teal"},
    {"red", "--matome-space-red"}
  ]

  def render(assigns) do
    assigns = assign(assigns, core: @core, badges: @badges, spaces: @spaces)

    ~H"""
    <div style="display:flex;flex-direction:column;gap:24px;padding:8px">
      <.swatch_group title="Core" swatches={@core} />
      <.swatch_group title="Badge tones" swatches={@badges} />
      <.swatch_group title="Spaces band" swatches={@spaces} />
    </div>
    """
  end

  defp swatch_group(assigns) do
    ~H"""
    <div>
      <h3 style="font-weight:700;margin-bottom:8px">{@title}</h3>
      <div style="display:flex;flex-wrap:wrap;gap:12px">
        <div :for={{name, var} <- @swatches} style="width:120px;font-size:12px">
          <div style={"height:56px;border-radius:8px;border:1px solid var(--matome-border);background:var(#{var})"}>
          </div>
          <div style="margin-top:4px;font-weight:600">{name}</div>
          <code style="opacity:0.7">{var}</code>
        </div>
      </div>
    </div>
    """
  end
end

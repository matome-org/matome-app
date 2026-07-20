defmodule MatomeApiWeb.AdminLive.Charts do
  @moduledoc """
  Lightweight SVG chart helpers for the admin landing dashboard.
  Not part of the Flutter-parity design system — admin-only.
  """
  use Phoenix.Component

  @gib 1024 * 1024 * 1024

  @doc "Format bytes as GiB with one decimal (e.g. `1.5 GiB`)."
  def format_gib(bytes) when is_integer(bytes) and bytes >= 0 do
    gib = bytes / @gib

    cond do
      bytes == 0 -> "0 GiB"
      gib < 0.1 and bytes > 0 -> "< 0.1 GiB"
      true -> :erlang.float_to_binary(gib, decimals: 1) <> " GiB"
    end
  end

  def format_gib(_), do: "0 GiB"

  attr :title, :string, required: true
  attr :segments, :list, required: true
  attr :empty_label, :string, default: "No data"

  def donut_chart(assigns) do
    total = Enum.reduce(assigns.segments, 0, fn seg, acc -> acc + seg.value end)
    segments = with_colors(assigns.segments)
    arcs = if total > 0, do: build_arcs(segments, total), else: []

    assigns =
      assigns
      |> assign(:total, total)
      |> assign(:segments, segments)
      |> assign(:arcs, arcs)

    ~H"""
    <figure class="admin-chart admin-chart--donut">
      <figcaption class="admin-chart__title">{@title}</figcaption>
      <div class="admin-chart__body">
        <svg
          class="admin-chart__svg"
          viewBox="0 0 42 42"
          role="img"
          aria-label={@title}
        >
          <circle
            class="admin-chart__track"
            cx="21"
            cy="21"
            r="15.915"
            fill="transparent"
            stroke-width="6"
          />
          <circle
            :for={arc <- @arcs}
            class="admin-chart__segment"
            cx="21"
            cy="21"
            r="15.915"
            fill="transparent"
            stroke={arc.color}
            stroke-width="6"
            stroke-dasharray={"#{arc.length} #{100 - arc.length}"}
            stroke-dashoffset={arc.offset}
          />
          <text
            :if={@total == 0}
            x="21"
            y="22.5"
            text-anchor="middle"
            class="admin-chart__empty-text"
          >
            —
          </text>
        </svg>
        <ul class="admin-chart__legend">
          <li :for={seg <- @segments} class="admin-chart__legend-item">
            <span class="admin-chart__swatch" style={"background: #{seg.color}"}></span>
            <span class="admin-chart__legend-label">{seg.label}</span>
            <span class="admin-chart__legend-value">{seg.value}</span>
          </li>
          <li :if={@segments == []} class="admin-chart__legend-item admin-chart__legend-item--empty">
            {@empty_label}
          </li>
        </ul>
      </div>
    </figure>
    """
  end

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :unit, :string, default: ""
  attr :empty_label, :string, default: "No data"
  attr :format, :atom, default: :raw

  def bar_chart(assigns) do
    max_value =
      assigns.rows
      |> Enum.map(& &1.value)
      |> Enum.max(fn -> 0 end)
      |> max(1)

    rows =
      assigns.rows
      |> Enum.with_index()
      |> Enum.map(fn {row, idx} ->
        Map.merge(row, %{
          color: row[:color] || palette_at(idx),
          pct: min(100, row.value / max_value * 100),
          display: format_bar_value(row.value, assigns.format, assigns.unit)
        })
      end)

    assigns = assign(assigns, :rows, rows)

    ~H"""
    <figure class="admin-chart admin-chart--bars">
      <figcaption class="admin-chart__title">{@title}</figcaption>
      <ul :if={@rows != []} class="admin-chart__bars" role="list">
        <li :for={row <- @rows} class="admin-chart__bar-row">
          <div class="admin-chart__bar-meta">
            <span class="admin-chart__bar-label">{row.label}</span>
            <span class="admin-chart__bar-value">{row.display}</span>
          </div>
          <div class="admin-chart__bar-track" aria-hidden="true">
            <div
              class="admin-chart__bar-fill"
              style={"width: #{row.pct}%; background: #{row.color}"}
            >
            </div>
          </div>
        </li>
      </ul>
      <p :if={@rows == []} class="admin-chart__empty">{@empty_label}</p>
    </figure>
    """
  end

  defp format_bar_value(value, :gib, _unit), do: format_gib(value)
  defp format_bar_value(value, :raw, ""), do: Integer.to_string(value)
  defp format_bar_value(value, :raw, unit), do: "#{value} #{unit}"

  defp with_colors(segments) do
    segments
    |> Enum.with_index()
    |> Enum.map(fn {seg, idx} ->
      Map.put(seg, :color, seg[:color] || palette_at(idx))
    end)
  end

  # Circumference of r=15.915 ≈ 100, so dasharray percentages map 1:1 to %.
  defp build_arcs(segments, total) do
    {arcs, _} =
      Enum.map_reduce(segments, 25.0, fn seg, offset ->
        length = seg.value / total * 100

        {%{
           color: seg.color,
           length: Float.round(length, 4),
           offset: Float.round(offset, 4)
         }, offset - length}
      end)

    arcs
  end

  defp palette_at(idx) do
    colors = [
      "var(--matome-space-blue)",
      "var(--matome-space-gold)",
      "var(--matome-space-green)",
      "var(--matome-space-teal)",
      "var(--matome-space-orange)",
      "var(--matome-space-rose)",
      "var(--matome-space-purple)",
      "var(--matome-badge-default)"
    ]

    Enum.at(colors, rem(idx, length(colors)))
  end
end

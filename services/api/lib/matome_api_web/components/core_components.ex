defmodule MatomeApiWeb.CoreComponents do
  @moduledoc """
  Minimal shared UI components for the /admin back-office (W0 #1868).

  Deliberately tiny for Wave 0: only the flash primitives the app layout
  needs. Later waves grow this into the real component library, all styled
  against the foundations tokens (see `assets/css/foundations.css`).
  """
  use Phoenix.Component

  @doc """
  Renders a single flash notice.
  """
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling"

  def flash(assigns) do
    ~H"""
    <p
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      role="alert"
      class={[
        "admin-flash",
        @kind == :info && "admin-flash--info",
        @kind == :error && "admin-flash--error"
      ]}
    >
      {msg}
    </p>
    """
  end

  @doc """
  Renders the info + error flash group.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <div class="admin-flash-group">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end

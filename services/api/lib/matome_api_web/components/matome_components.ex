defmodule MatomeApiWeb.MatomeComponents do
  @moduledoc """
  Base-tier design-system components for the `/admin` back-office (W1 #1869).

  A server-side HEEx port of the Flutter `flutter_widgetbook` BASE TIER
  (`Components/Atoms/*`) — buttons, form fields, feedback, avatars, status,
  relation chips, and detail-panel atoms. Every component is a plain
  `Phoenix.Component` function component that styles itself only through the W0
  foundations tokens (`assets/css/foundations.css`) via the semantic classes in
  `assets/css/components.css`. There are ZERO hardcoded colors/spacing/type in
  this module — all visual values live in the token-driven stylesheet.

  SSOT parity: `apps/flutter/lib/ui/*.dart` + `features/auth/auth_widgets.dart`.
  Drift is eyeballed against `notebooks/components_catalog.livemd`; accepted
  deviations are logged in `docs/design-system-reconciliation.md`.

  Material glyphs have no server font, so the leading icons here are lightweight
  inline SVGs (approximations, `currentColor` + `1em`) — see `icon/1`.
  """
  use Phoenix.Component

  # ─── Buttons ────────────────────────────────────────────────────────────────

  @doc """
  Filled primary action button (Flutter `PrimaryButton`).

  Variants: default, `icon` (leading glyph), `disabled`.
  """
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :icon, :string, default: nil, doc: "optional leading icon name (see icon/1)"
  attr :rest, :global
  slot :inner_block, required: true

  def primary_button(assigns) do
    ~H"""
    <button type={@type} class="matome-btn matome-btn--primary" disabled={@disabled} {@rest}>
      <.icon :if={@icon} name={@icon} />
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Low-emphasis text action button (Flutter `AppTextButton`).
  """
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :icon, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def text_button(assigns) do
    ~H"""
    <button type={@type} class="matome-btn matome-btn--text" disabled={@disabled} {@rest}>
      <.icon :if={@icon} name={@icon} />
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Icon-only button (admin-generic; no discrete widgetbook atom).
  """
  attr :name, :string, required: true, doc: "icon name (see icon/1)"
  attr :label, :string, required: true, doc: "accessible label"
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def icon_button(assigns) do
    ~H"""
    <button type="button" class="matome-icon-btn" disabled={@disabled} aria-label={@label} {@rest}>
      <.icon name={@name} />
    </button>
    """
  end

  @doc """
  Full-width submit button with a loading state (Flutter `AuthSubmitButton`).

  States: idle, `loading` (spinner, disabled), `disabled`.
  """
  attr :type, :string, default: "submit"
  attr :loading, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def submit_button(assigns) do
    ~H"""
    <button
      type={@type}
      class="matome-btn matome-btn--submit"
      disabled={@disabled or @loading}
      aria-busy={to_string(@loading)}
      {@rest}
    >
      <span :if={@loading} class="matome-spinner matome-spinner--sm" aria-hidden="true"></span>
      <span :if={not @loading}>{render_slot(@inner_block)}</span>
    </button>
    """
  end

  # ─── Form fields ────────────────────────────────────────────────────────────

  @doc """
  Labeled text input (Flutter `AppTextField` / `AuthField`).

  States: default, hint, `obscure` (password), `disabled`.
  """
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :value, :string, default: nil
  attr :hint, :string, default: nil, doc: "placeholder text"
  attr :obscure, :boolean, default: false, doc: "render as a password field"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(autocomplete inputmode readonly required)

  def text_field(assigns) do
    ~H"""
    <label class="matome-field">
      <span :if={@label} class="matome-field__label">{@label}</span>
      <input
        type={if @obscure, do: "password", else: "text"}
        name={@name}
        value={@value}
        placeholder={@hint}
        disabled={@disabled}
        class="matome-field__control"
        {@rest}
      />
    </label>
    """
  end

  @doc """
  Labeled `<select>` (admin-generic; field-family styling of `AppTextField`).
  """
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :options, :list, default: [], doc: "list of {label, value} or values"
  attr :value, :string, default: nil
  attr :rest, :global
  slot :inner_block

  def select(assigns) do
    ~H"""
    <label class="matome-field">
      <span :if={@label} class="matome-field__label">{@label}</span>
      <select name={@name} disabled={@disabled} class="matome-field__control" {@rest}>
        {render_slot(@inner_block)}
        <option :for={opt <- @options} value={option_value(opt)} selected={option_value(opt) == @value}>
          {option_label(opt)}
        </option>
      </select>
    </label>
    """
  end

  @doc """
  Checkbox with an inline label (admin-generic; field family).
  """
  attr :name, :string, default: nil
  attr :checked, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def checkbox(assigns) do
    ~H"""
    <label class="matome-checkbox">
      <input
        type="checkbox"
        name={@name}
        checked={@checked}
        disabled={@disabled}
        class="matome-checkbox__box"
        {@rest}
      />
      <span>{render_slot(@inner_block)}</span>
    </label>
    """
  end

  # ─── Feedback ───────────────────────────────────────────────────────────────

  @doc """
  Centered empty-state message (Flutter `EmptyState`).

  The `icon` slot carries the decorative glyph (emoji/SVG) — the server has no
  Material icon font.
  """
  attr :title, :string, required: true
  attr :message, :string, default: nil
  slot :icon

  def empty_state(assigns) do
    ~H"""
    <div class="matome-empty">
      <div :if={@icon != []} class="matome-empty__icon">{render_slot(@icon)}</div>
      <div class="matome-empty__title">{@title}</div>
      <div :if={@message} class="matome-empty__message">{@message}</div>
    </div>
    """
  end

  @doc """
  Indeterminate loading spinner (Flutter `LoadingIndicator`).

  Sizes: `sm`, `md`, `lg`.
  """
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :label, :string, default: "Loading"

  def loading_indicator(assigns) do
    ~H"""
    <span class={["matome-spinner", "matome-spinner--#{@size}"]} role="status" aria-label={@label}></span>
    """
  end

  @doc """
  Inline error banner (Flutter `AuthErrorBanner`).
  """
  attr :message, :string, required: true

  def error_banner(assigns) do
    ~H"""
    <div class="matome-banner matome-banner--error" role="alert">
      <.icon name="error" class="matome-banner__icon" />
      <span>{@message}</span>
    </div>
    """
  end

  @doc """
  Positive/notice banner, e.g. "reset link sent" (Flutter `AuthNoticeBanner`).
  """
  attr :message, :string, required: true

  def notice_banner(assigns) do
    ~H"""
    <div class="matome-banner matome-banner--notice" role="status">
      <.icon name="check" class="matome-banner__icon" />
      <span>{@message}</span>
    </div>
    """
  end

  # ─── Avatars ────────────────────────────────────────────────────────────────

  @doc """
  Circular avatar for initials or an icon (Flutter `Avatar`).

  Sizes: `sm`, `md`, `lg`.
  """
  attr :initials, :string, default: nil
  attr :icon, :string, default: nil
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :label, :string, default: nil, doc: "accessible label"
  attr :rest, :global

  def avatar(assigns) do
    ~H"""
    <span class={["matome-avatar", "matome-avatar--#{@size}"]} aria-label={@label} {@rest}>
      <.icon :if={@icon} name={@icon} />
      <span :if={@initials && !@icon}>{@initials}</span>
    </span>
    """
  end

  @doc """
  Overlapping people initials with a `+N` overflow chip (Flutter `PeopleCluster`).
  """
  attr :names, :list, required: true
  attr :max_shown, :integer, default: 3
  attr :size, :string, default: "sm", values: ~w(sm md lg)

  def people_cluster(assigns) do
    shown = Enum.take(assigns.names, assigns.max_shown)
    extra = length(assigns.names) - length(shown)
    assigns = assign(assigns, shown: shown, extra: extra)

    ~H"""
    <span :if={@names != []} class="matome-cluster" title={Enum.join(@names, ", ")}>
      <span :for={n <- @shown} class={["matome-avatar", "matome-avatar--#{@size}"]}>
        {String.first(n)}
      </span>
      <span
        :if={@extra > 0}
        class={["matome-avatar", "matome-avatar--#{@size}", "matome-cluster__overflow"]}
      >
        +{@extra}
      </span>
    </span>
    """
  end

  # ─── Status ─────────────────────────────────────────────────────────────────

  @doc """
  Dotted status pill (Flutter `StatusBadge.label`).

  Tones: `work`, `personal`, `ideas`, `default`.
  """
  attr :label, :string, required: true
  attr :tone, :string, default: "default", values: ~w(work personal ideas default)
  attr :dot, :boolean, default: true

  def status_badge(assigns) do
    ~H"""
    <span class={["matome-badge", "matome-badge--#{@tone}"]}>
      <span :if={@dot} class="matome-badge__dot"></span>
      <span>{@label}</span>
    </span>
    """
  end

  @doc """
  Compact sync-status chip (Flutter `MatomeSyncChip` / `StatusBadge.sync`).

  States: `cloud`, `syncing`, `on_device`.
  """
  attr :state, :string, required: true, values: ~w(cloud syncing on_device)
  attr :label, :string, default: nil, doc: "overrides the default state label"

  def sync_chip(assigns) do
    {icon, default_label, modifier} =
      case assigns.state do
        "cloud" -> {"cloud_done", "Cloud", "cloud"}
        "syncing" -> {"cloud_sync", "Syncing", "syncing"}
        "on_device" -> {"cloud_off", "On device", "on-device"}
      end

    assigns = assign(assigns, icon: icon, default_label: default_label, modifier: modifier)

    ~H"""
    <span class={["matome-sync-chip", "matome-sync-chip--#{@modifier}"]}>
      <.icon name={@icon} class="matome-sync-chip__icon" />
      <span>{@label || @default_label}</span>
    </span>
    """
  end

  # ─── Relation chips ─────────────────────────────────────────────────────────

  @doc """
  Filled matome-relation pill (Flutter `MatomeChip`).

  When `matome` is nil the chip renders the italic muted "Unfiled" state.
  """
  attr :matome, :string, default: nil
  attr :unfiled_label, :string, default: "Unfiled"

  def matome_chip(assigns) do
    ~H"""
    <span class={["matome-chip", "matome-chip--matome", @matome == nil && "matome-chip--empty"]}>
      <.icon name={if @matome, do: "workspaces", else: "inbox"} />
      <span class="matome-chip__label">{@matome || @unfiled_label}</span>
    </span>
    """
  end

  @doc """
  Outlined space-relation pill (Flutter `SpaceChip`).

  When `space` is nil the chip renders the italic muted "Inbox" state.
  """
  attr :space, :string, default: nil
  attr :inbox_label, :string, default: "Inbox"

  def space_chip(assigns) do
    ~H"""
    <span class={["matome-chip", "matome-chip--space", @space == nil && "matome-chip--empty"]}>
      <.icon name={if @space, do: "folder", else: "inbox"} />
      <span class="matome-chip__label">{@space || @inbox_label}</span>
    </span>
    """
  end

  @doc """
  Role pill tinted by role (Flutter `RoleChip`).

  Roles: `organizer`, `speaker`, `attendee`.
  """
  attr :role, :string, required: true, values: ~w(organizer speaker attendee)
  attr :label, :string, default: nil

  def role_chip(assigns) do
    ~H"""
    <span class={["matome-role-chip", "matome-role-chip--#{@role}"]}>
      {@label || String.capitalize(@role)}
    </span>
    """
  end

  @doc """
  Document media header chip (Flutter `FileTypeChip`).

  Renders a type-icon tile, the file name + size, and a DISABLED "Open · soon"
  affordance (preview is deferred, matching the widgetbook).
  """
  attr :file_name, :string, required: true
  attr :size_label, :string, default: nil
  attr :unknown_size_label, :string, default: "—"
  attr :open_label, :string, default: "Open"
  attr :soon_label, :string, default: "soon"

  def file_type_chip(assigns) do
    ~H"""
    <div class="matome-file-chip">
      <span class="matome-file-chip__icon"><.icon name="file" /></span>
      <div class="matome-file-chip__body">
        <div class="matome-file-chip__name">{@file_name}</div>
        <div class="matome-file-chip__size">{@size_label || @unknown_size_label}</div>
      </div>
      <div class="matome-file-chip__open">
        <.text_button disabled icon="open">{@open_label}</.text_button>
        <span class="matome-file-chip__soon">{@soon_label}</span>
      </div>
    </div>
    """
  end

  # ─── Panel atoms ────────────────────────────────────────────────────────────

  @doc """
  Labeled detail-panel section with an optional trailing action + divider
  (Flutter `MatomePanelSection`).
  """
  attr :label, :string, required: true
  attr :show_divider, :boolean, default: true
  slot :action
  slot :inner_block, required: true

  def panel_section(assigns) do
    ~H"""
    <section class="matome-panel-section">
      <div class="matome-panel-section__head">
        <span class="matome-panel-section__label">{@label}</span>
        <span :if={@action != []} class="matome-panel-section__action">{render_slot(@action)}</span>
      </div>
      <div class="matome-panel-section__body">{render_slot(@inner_block)}</div>
      <hr :if={@show_divider} class="matome-panel-section__divider" />
    </section>
    """
  end

  @doc """
  Compact detail-panel item row: leading icon/slot, title, optional meta, and an
  optional trailing slot (Flutter `MatomePanelRow`).
  """
  attr :icon, :string, default: nil
  attr :title, :string, required: true
  attr :meta, :string, default: nil
  slot :leading
  slot :trailing

  def panel_row(assigns) do
    ~H"""
    <div class="matome-panel-row">
      <span :if={@leading != []}>{render_slot(@leading)}</span>
      <span :if={@leading == [] && @icon} class="matome-panel-row__icon"><.icon name={@icon} /></span>
      <div class="matome-panel-row__body">
        <div class="matome-panel-row__title">{@title}</div>
        <div :if={@meta} class="matome-panel-row__meta">{@meta}</div>
      </div>
      <span :if={@trailing != []}>{render_slot(@trailing)}</span>
    </div>
    """
  end

  @doc """
  Accent "Add …" affordance row for a panel section (Flutter `MatomePanelAddRow`).
  """
  attr :label, :string, required: true
  attr :icon, :string, default: "add"
  attr :rest, :global
  slot :inner_block

  def panel_add_row(assigns) do
    ~H"""
    <button type="button" class="matome-panel-add" {@rest}>
      <.icon name={@icon} class="matome-panel-add__icon" />
      <span>{@label}</span>
    </button>
    """
  end

  # ─── Icon primitive ─────────────────────────────────────────────────────────

  @doc """
  Inline SVG icon (approximation of the Flutter Material glyph).

  The server has no Material icon font, so these are lightweight hand-authored
  24×24 line glyphs drawn with `currentColor` at `1em` — they scale with the
  host font-size and inherit the host color, both token-driven. See the icon
  inventory in `notebooks/foundations_catalog.livemd`.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(assigns) do
    ~H"""
    <svg
      class={["matome-icon", @class]}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      {Phoenix.HTML.raw(icon_paths(@name))}
    </svg>
    """
  end

  # Path data only (geometry — no colors, no px). currentColor + 1em do the rest.
  defp icon_paths("check"), do: ~s(<path d="M20 6 9 17l-5-5"/>)
  defp icon_paths("close"), do: ~s(<path d="M18 6 6 18M6 6l12 12"/>)

  defp icon_paths("error"),
    do: ~s(<circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>)

  defp icon_paths("add"), do: ~s(<path d="M12 5v14M5 12h14"/>)

  defp icon_paths("cloud"),
    do: ~s(<path d="M7 18a4 4 0 0 1 0-8 5 5 0 0 1 9.6-1.3A3.5 3.5 0 1 1 17 18Z"/>)

  defp icon_paths("cloud_done"),
    do:
      ~s(<path d="M7 18a4 4 0 0 1 0-8 5 5 0 0 1 9.6-1.3A3.5 3.5 0 1 1 17 18Z"/><path d="m9 13 2 2 4-4"/>)

  defp icon_paths("cloud_sync"),
    do:
      ~s(<path d="M7 18a4 4 0 0 1 0-8 5 5 0 0 1 9.6-1.3A3.5 3.5 0 1 1 17 18Z"/><path d="M10 12a2.5 2.5 0 0 1 4-1M14 15a2.5 2.5 0 0 1-4 1"/>)

  defp icon_paths("cloud_off"),
    do:
      ~s(<path d="M7 18a4 4 0 0 1-.5-8 5 5 0 0 1 7-3.5M17 18a3.5 3.5 0 0 0 1-6.8"/><path d="M3 3l18 18"/>)

  defp icon_paths("folder"),
    do: ~s(<path d="M3 7a2 2 0 0 1 2-2h4l2 2h6a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>)

  defp icon_paths("inbox"),
    do:
      ~s(<path d="M4 13h4l2 3h4l2-3h4"/><path d="M4 13 6 5h12l2 8v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Z"/>)

  defp icon_paths("workspaces"),
    do: ~s(<circle cx="8" cy="8" r="3"/><circle cx="16" cy="8" r="3"/><circle cx="12" cy="16" r="3"/>)

  defp icon_paths("person"),
    do: ~s(<circle cx="12" cy="8" r="4"/><path d="M5 21a7 7 0 0 1 14 0"/>)

  defp icon_paths("person_add"),
    do:
      ~s(<circle cx="10" cy="8" r="4"/><path d="M3 21a7 7 0 0 1 12-5"/><path d="M18 14v6M15 17h6"/>)

  defp icon_paths("file"),
    do: ~s(<path d="M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M14 3v4h4"/>)

  defp icon_paths("open"),
    do:
      ~s(<path d="M14 4h6v6"/><path d="M20 4 11 13"/><path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4"/>)

  defp icon_paths("share"),
    do:
      ~s(<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5 15.4 17.5M15.4 6.5 8.6 10.5"/>)

  defp icon_paths(_other), do: ~s(<circle cx="12" cy="12" r="9"/>)

  # ─── Private helpers ────────────────────────────────────────────────────────

  defp option_value({_label, value}), do: value
  defp option_value(value), do: value

  defp option_label({label, _value}), do: label
  defp option_label(value), do: value
end

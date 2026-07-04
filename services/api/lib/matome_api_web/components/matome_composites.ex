defmodule MatomeApiWeb.MatomeComposites do
  @moduledoc """
  Composite-tier design-system components for the `/admin` back-office (W2 #1870).

  A server-side HEEx port of the Flutter `flutter_widgetbook` COMPOSITE tier —
  the data table, nav shell, list rows, detail panel, contact detail, and file
  card the admin data-LiveViews (W6/W7) render on. Every composite is
  **assembled from the W1 base atoms** in `MatomeApiWeb.MatomeComponents` (the
  buttons/chips/avatars/panel atoms), not re-styled from scratch: this module
  only adds the LAYOUT scaffolding that arranges those atoms. All visual values
  come from the W0 foundations tokens via `assets/css/composites.css` — there
  are ZERO hardcoded colors/spacing/type here.

  SSOT parity: `apps/flutter/lib/{ui,features}/*.dart`. Drift is eyeballed
  against `notebooks/composites_catalog.livemd`; accepted deviations are logged
  in `docs/design-system-reconciliation.md`.

  The graduated widgetbook proposals converge onto these same widgets:
  "matome table"/"files table" -> `data_table/1`, "nav rework" ->
  `nav_sidebar/1` + `nav_dock/1`, "contact detail" -> `contact_detail/1`,
  "files grid" -> `file_card/1`.
  """
  use Phoenix.Component

  import MatomeApiWeb.MatomeComponents

  # ─── Data table (MatomeTable / FilesTable) ──────────────────────────────────

  @doc """
  Generic selectable, sortable data table (Flutter `MatomeTable` / `FilesTable`).

  Both Flutter tables share identical geometry + machinery, so this is ONE
  primitive parameterized by `:col` slots. Columns declare a `label`, an
  optional `sortable` + `sort_key`, an `align`, and a fixed-width `width`
  bucket (`when|items|people|space|sync|size|matome`; omit for the flexible
  primary column). Selection renders a leading checkbox column + a bulk bar
  (with the `:bulk_actions` slot) when `selected` is non-empty; `active_id`
  tints the row open in a reading pane; an empty `rows` list renders the
  base `empty_state/1`.
  """
  attr :rows, :list, required: true
  attr :row_id, :any, default: &__MODULE__.default_row_id/1, doc: "row -> id fun"
  attr :selectable, :boolean, default: false
  attr :selected, :list, default: []
  attr :active_id, :any, default: nil
  attr :sort_key, :string, default: nil
  attr :sort_dir, :string, default: "asc", values: ~w(asc desc)
  attr :empty_title, :string, default: "Nothing here yet"
  attr :empty_message, :string, default: nil

  slot :col do
    attr :label, :string
    attr :sortable, :boolean
    attr :sort_key, :string
    attr :align, :string
    attr :width, :string
  end

  slot :bulk_actions

  def data_table(assigns) do
    ~H"""
    <div class="matome-table">
      <div :if={@selectable and @selected != []} class="matome-table__bulkbar">
        <.icon_button name="close" label="Clear selection" />
        <span class="matome-table__bulkbar-count">{length(@selected)} selected</span>
        <span :if={@bulk_actions != []} class="matome-table__bulkbar-actions">
          {render_slot(@bulk_actions)}
        </span>
      </div>

      <div class="matome-table__head">
        <span :if={@selectable} class="matome-table__check">
          <input type="checkbox" class="matome-checkbox__box" aria-label="Select all" />
        </span>
        <div :for={col <- @col} class={cell_class(col)}>
          <button
            :if={col[:sortable]}
            type="button"
            class={["matome-table__sort", col[:sort_key] == @sort_key && "matome-table__sort--active"]}
          >
            <span>{col[:label]}</span>
            <.icon
              name={sort_icon(col[:sort_key] == @sort_key, @sort_dir)}
              class="matome-table__sort-icon"
            />
          </button>
          <span :if={!col[:sortable]} class="matome-table__collabel">{col[:label]}</span>
        </div>
      </div>

      <.empty_state :if={@rows == []} title={@empty_title} message={@empty_message}>
        <:icon><.icon name="inbox" /></:icon>
      </.empty_state>

      <div
        :for={row <- @rows}
        class={[
          "matome-table__row",
          @row_id.(row) in @selected && "matome-table__row--selected",
          @row_id.(row) == @active_id && "matome-table__row--active"
        ]}
      >
        <span :if={@selectable} class="matome-table__check">
          <input
            type="checkbox"
            class="matome-checkbox__box"
            checked={@row_id.(row) in @selected}
            aria-label="Select row"
          />
        </span>
        <div :for={col <- @col} class={cell_class(col)}>{render_slot(col, row)}</div>
      </div>
    </div>
    """
  end

  @doc """
  Primary-cell title + summary line for a table row (Flutter `_DataRow` title).
  """
  attr :title, :string, required: true
  attr :summary, :string, default: nil
  attr :empty_summary, :string, default: "No summary yet"

  def table_primary_cell(assigns) do
    ~H"""
    <div class="matome-table__cell--flex">
      <div class="matome-table__title">{@title}</div>
      <div class={["matome-table__summary", @summary in [nil, ""] && "matome-table__summary--empty"]}>
        {@summary || @empty_summary}
      </div>
    </div>
    """
  end

  @doc """
  Small icon+count token for the table Items / People cells (Flutter `_IconCount`).
  Renders a muted em-dash when `count` is nil or zero.
  """
  attr :icon, :string, required: true
  attr :count, :integer, default: nil

  def table_count(assigns) do
    ~H"""
    <span :if={@count && @count > 0} class="matome-table__count">
      <.icon name={@icon} /><span>{@count}</span>
    </span>
    <span :if={!@count || @count == 0} class="matome-table__dash">—</span>
    """
  end

  # ─── Nav shell: sidebar / dock / fab ────────────────────────────────────────

  @doc """
  Collapsible desktop navigation sidebar (Flutter `MatomeSidebar`).

  `destinations` are `%{id, icon, label}` maps; `active_id` tints the current
  one; `collapsed` swaps to the 76px icon rail (labels/wordmark hidden by CSS).
  Composes the base `avatar/1`, `icon/1`, and `icon_button/1`.
  """
  attr :destinations, :list, required: true
  attr :active_id, :any, default: nil
  attr :collapsed, :boolean, default: false
  attr :account_name, :string, default: "Account"
  attr :add_label, :string, default: "Add"

  def nav_sidebar(assigns) do
    ~H"""
    <nav class={["matome-sidebar", @collapsed && "matome-sidebar--collapsed"]}>
      <div class="matome-sidebar__header">
        <span class="matome-sidebar__wordmark">matome</span>
        <.icon_button name={if @collapsed, do: "menu", else: "menu_open"} label="Toggle sidebar" />
      </div>

      <div class="matome-sidebar__add">
        <button type="button" class={["matome-nav-add", @collapsed && "matome-nav-add--tile"]}>
          <.icon name="add" />
          <span :if={!@collapsed} class="matome-nav-add__label">{@add_label}</span>
          <.icon :if={!@collapsed} name="expand_more" />
        </button>
      </div>

      <div class="matome-sidebar__nav">
        <button
          :for={d <- @destinations}
          type="button"
          class={["matome-nav-item", d.id == @active_id && "matome-nav-item--active"]}
        >
          <span class="matome-nav-item__icon"><.icon name={d.icon} /></span>
          <span class="matome-nav-item__label">{d.label}</span>
        </button>
      </div>

      <div class="matome-sidebar__footer">
        <button type="button" class="matome-nav-item">
          <span class="matome-nav-item__icon"><.icon name="settings" /></span>
          <span class="matome-nav-item__label">Settings</span>
        </button>
        <div class="matome-nav-item">
          <.avatar initials={initials(@account_name)} size="sm" />
          <span class="matome-sidebar__footer-name">{@account_name}</span>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Mobile icon-only bottom navigation dock (Flutter `MatomeBottomDock`).

  Optionally trails a settings `avatar/1` when `account_name` is given.
  """
  attr :destinations, :list, required: true
  attr :active_id, :any, default: nil
  attr :account_name, :string, default: nil

  def nav_dock(assigns) do
    ~H"""
    <nav class="matome-dock">
      <button
        :for={d <- @destinations}
        type="button"
        class={["matome-dock__item", d.id == @active_id && "matome-dock__item--active"]}
        aria-label={d.label}
      >
        <.icon name={d.icon} />
      </button>
      <.avatar :if={@account_name} initials={initials(@account_name)} size="md" label="Settings" />
    </nav>
    """
  end

  @doc """
  Offset accent add FAB (Flutter `MatomeAddFab`). Host-positioned; standalone here.
  """
  attr :icon, :string, default: "add"
  attr :label, :string, default: "Add"

  def nav_fab(assigns) do
    ~H"""
    <button type="button" class="matome-fab" aria-label={@label}>
      <.icon name={@icon} />
    </button>
    """
  end

  @doc """
  Two-pane master/detail scaffold (Flutter `MasterDetailScaffold`).

  Renders the `:master` slot in the left pane and the `:detail` slot (falling
  back to `:empty`) in the right. `show_close` adds the reading-pane close bar.
  """
  attr :show_close, :boolean, default: false
  attr :close_label, :string, default: "Close pane"
  slot :master, required: true
  slot :detail
  slot :empty

  def master_detail(assigns) do
    ~H"""
    <div class="matome-masterdetail">
      <div class="matome-masterdetail__master">{render_slot(@master)}</div>
      <div class="matome-masterdetail__divider"></div>
      <div class="matome-masterdetail__pane">
        <div :if={@show_close} class="matome-masterdetail__closebar">
          <.icon_button name="close" label={@close_label} />
        </div>
        <div :if={@detail != []}>{render_slot(@detail)}</div>
        <div :if={@detail == []}>{render_slot(@empty)}</div>
      </div>
    </div>
    """
  end

  # ─── List rows ──────────────────────────────────────────────────────────────

  @doc """
  Generic list row (Flutter `InboxItemCard` shape): leading icon/slot, a title
  with an optional bordered `tag`, a meta line, and a `:footer` slot (sync
  chip + accent affordance) plus an optional `:trailing` slot.
  """
  attr :icon, :string, default: nil
  attr :title, :string, required: true
  attr :meta, :string, default: nil
  attr :tag, :string, default: nil
  slot :leading
  slot :footer
  slot :trailing

  def list_row(assigns) do
    ~H"""
    <div class="matome-list-row">
      <span :if={@leading != []} class="matome-list-row__leading">{render_slot(@leading)}</span>
      <span :if={@leading == [] && @icon} class="matome-list-row__leading"><.icon name={@icon} /></span>
      <div class="matome-list-row__body">
        <div class="matome-list-row__titlerow">
          <span class="matome-list-row__title">{@title}</span>
          <span :if={@tag} class="matome-kind-tag">{@tag}</span>
        </div>
        <div :if={@meta} class="matome-list-row__meta">{@meta}</div>
        <div :if={@footer != []} class="matome-list-row__footer">{render_slot(@footer)}</div>
      </div>
      <span :if={@trailing != []} class="matome-list-row__trailing">{render_slot(@trailing)}</span>
    </div>
    """
  end

  @doc """
  Contact list tile (Flutter `ContactTile`): tinted initial/person swatch, name,
  optional notes line, and a chevron. `color` is a spaces-band token name.
  """
  attr :name, :string, required: true
  attr :notes, :string, default: nil
  attr :color, :string, default: "gold", doc: "spaces band: gold|green|blue|orange|rose|purple|teal|red"
  attr :selected, :boolean, default: false

  def contact_tile(assigns) do
    ~H"""
    <button type="button" class={["matome-contact-tile", @selected && "matome-contact-tile--selected"]}>
      <span class="matome-contact-tile__swatch" style={swatch_style(@color)}>
        <.icon name="person" />
      </span>
      <div class="matome-contact-tile__body">
        <div class="matome-contact-tile__name">{@name}</div>
        <div :if={@notes not in [nil, ""]} class="matome-contact-tile__notes">{@notes}</div>
      </div>
      <.icon name="chevron_right" class="matome-list-row__chevron" />
    </button>
    """
  end

  @doc """
  Multi-variant content card (Flutter `AppCard`).

  Variants: `matome` (title + summary + wrapping `:meta` strip + `:trailing`
  actions), `calendar` (badge dot + `status_badge/1` + duration + chevron),
  `recording` (state avatar + state line + `status_badge/1`/`sync_chip/1`
  footer; `state` ∈ done|processing|failed|pending).
  """
  attr :variant, :string, default: "matome", values: ~w(matome calendar recording)
  attr :title, :string, required: true
  attr :selected, :boolean, default: false
  # matome
  attr :summary, :string, default: nil
  # calendar
  attr :badge, :string, default: "default"
  attr :badge_label, :string, default: nil
  attr :duration, :string, default: nil
  # recording
  attr :state, :string, default: "done", values: ~w(done processing failed pending)
  attr :media, :string, default: "audio"
  attr :body, :string, default: nil
  attr :status_tone, :string, default: nil
  attr :status_label, :string, default: nil
  attr :sync, :string, default: "cloud"
  slot :meta
  slot :trailing

  def app_card(%{variant: "calendar"} = assigns) do
    ~H"""
    <button type="button" class="matome-card matome-card--calendar">
      <span class={["matome-card__dot", @badge == "work" && "matome-card__dot--work"]}></span>
      <div class="matome-card__body">
        <div class="matome-card__title">{@title}</div>
        <div class="matome-card__footer">
          <.status_badge :if={@badge_label} label={@badge_label} tone={@badge} dot={false} />
          <span :if={@duration} class="matome-card__duration">{@duration}</span>
        </div>
      </div>
      <.icon name="chevron_right" class="matome-list-row__chevron" />
    </button>
    """
  end

  def app_card(%{variant: "recording"} = assigns) do
    ~H"""
    <div class="matome-card">
      <span class={["matome-card__avatar", avatar_state_class(@state)]}>
        <.loading_indicator :if={@state == "processing"} size="sm" />
        <.icon :if={@state == "failed"} name="warning" />
        <.icon :if={@state == "pending"} name="cloud_off" />
        <.icon :if={@state == "done"} name={media_icon(@media)} />
      </span>
      <div class="matome-card__body">
        <div class="matome-card__title">{@title}</div>
        <div :if={@state == "pending"} class="matome-card__row">
          <.icon name="cloud_off" /><span>Pending upload</span>
        </div>
        <div :if={@state == "processing"} class="matome-card__row matome-card__row--processing">
          <span>Processing…</span>
        </div>
        <div :if={@state == "failed"} class="matome-card__row matome-card__row--failed">
          <.icon name="error" /><span>Upload failed</span>
          <.text_button icon="refresh">Retry</.text_button>
        </div>
        <div :if={@state == "done" && @body} class="matome-card__summary">{@body}</div>
        <div class="matome-card__footer">
          <.status_badge :if={@status_label} label={@status_label} tone={@status_tone || "default"} />
          <.sync_chip state={@sync} />
          <span :if={@duration} class="matome-card__duration">{@duration}</span>
        </div>
      </div>
    </div>
    """
  end

  def app_card(assigns) do
    ~H"""
    <button type="button" class={["matome-card", @selected && "matome-card--selected"]}>
      <div class="matome-card__body">
        <div class="matome-card__title">{@title}</div>
        <div class={["matome-card__summary", @summary in [nil, ""] && "matome-card__summary--empty"]}>
          {@summary || "No summary yet"}
        </div>
        <div :if={@meta != []} class="matome-card__meta">{render_slot(@meta)}</div>
      </div>
      <span :if={@trailing != []}>{render_slot(@trailing)}</span>
    </button>
    """
  end

  @doc """
  subtle-fill place chip for a card meta strip (Flutter `_MatomePlaceChip`).
  Renders the space name, or a muted "Inbox" when `space` is nil.
  """
  attr :space, :string, default: nil
  attr :inbox_label, :string, default: "Inbox"

  def place_chip(assigns) do
    ~H"""
    <span class="matome-place-chip">
      <.icon name={if @space, do: "folder", else: "inbox"} />
      <span>{@space || @inbox_label}</span>
    </span>
    """
  end

  @doc """
  Icon+count meta token for a card meta strip (Flutter `_MatomeMetaToken`).
  """
  attr :icon, :string, required: true
  attr :label, :string, required: true

  def meta_token(assigns) do
    ~H"""
    <span class="matome-card__meta-token"><.icon name={@icon} /><span>{@label}</span></span>
    """
  end

  # ─── Detail panel (assembled MatomeDetailPanel) ─────────────────────────────

  @doc """
  Assembled matome detail panel (Flutter `MatomeDetailPanel`).

  Stacks the W1 panel atoms in the fixed IA order: header, Items, People,
  Space, Notes, Share. `items` are `%{media, title, meta, sync}`; `contacts`
  are `%{initial, name, role}`; a nil/blank `space_name` renders the Inbox
  "file into space" affordance. Composes `panel_section/1`, `panel_row/1`,
  `panel_add_row/1`, `sync_chip/1`, and `avatar/1`.
  """
  attr :title, :string, default: "Detail"
  attr :items, :list, default: []
  attr :contacts, :list, default: []
  attr :space_name, :string, default: nil
  attr :notes, :string, default: nil
  attr :show_header, :boolean, default: true
  attr :add_item_label, :string, default: "Add item"
  attr :add_person_label, :string, default: "Add person"
  attr :space_label, :string, default: "Space"
  attr :refile_label, :string, default: "Refile"
  attr :file_into_space_label, :string, default: "File into space"
  attr :notes_label, :string, default: "Notes"
  attr :notes_edit_label, :string, default: "Edit"
  attr :share_label, :string, default: "Share"

  def detail_panel(assigns) do
    ~H"""
    <div class="matome-detail-panel">
      <div :if={@show_header} class="matome-detail-panel__header">
        <span class="matome-detail-panel__title">{@title}</span>
        <.icon_button name="close" label="Close" />
      </div>

      <.panel_section label={"Items · #{length(@items)}"}>
        <.panel_row
          :for={it <- @items}
          icon={matome_item_icon(it.media)}
          title={it.title}
          meta={it[:meta]}
        >
          <:trailing><.sync_chip state={it.sync} /></:trailing>
        </.panel_row>
        <.panel_add_row label={@add_item_label} />
      </.panel_section>

      <.panel_section label={"People · #{length(@contacts)}"}>
        <.panel_row :for={c <- @contacts} title={c.name} meta={c[:role]}>
          <:leading><.avatar initials={c.initial} size="sm" /></:leading>
        </.panel_row>
        <.panel_add_row label={@add_person_label} icon="person_add" />
      </.panel_section>

      <.panel_section label={@space_label}>
        <div :if={inbox?(@space_name)} class="matome-detail-panel__space">
          <.panel_add_row label={@file_into_space_label} icon="folder" />
        </div>
        <div :if={!inbox?(@space_name)} class="matome-detail-panel__space">
          <.icon name="folder" />
          <span class="matome-detail-panel__space-name">{@space_name}</span>
          <.text_button>{@refile_label}</.text_button>
        </div>
      </.panel_section>

      <.panel_section label={@notes_label} show_divider={false}>
        <:action><.text_button>{@notes_edit_label}</.text_button></:action>
        <div class="matome-detail-panel__notes">{@notes}</div>
      </.panel_section>

      <button type="button" class="matome-detail-panel__share">
        <.icon name="share" /><span>{@share_label}</span>
      </button>
    </div>
    """
  end

  # ─── Contact detail (graduated proposal) ────────────────────────────────────

  @doc """
  Assembled contact detail (Flutter `ContactDetail`, graduated proposal).

  Header (avatar + identity + `sync_chip/1` + actions) over a two-column body:
  an identity column (`info_row/1`s + notes) and a relations column (Matomes
  with `role_chip/1`, Spaces as `space_chip/1`s, Files). Composes `avatar/1`,
  `sync_chip/1`, `role_chip/1`, `space_chip/1`, `panel_section/1`, `panel_row/1`.
  """
  attr :name, :string, required: true
  attr :subtitle, :string, default: nil
  attr :color, :string, default: "gold"
  attr :sync, :string, default: "cloud"
  attr :email, :string, default: nil
  attr :phone, :string, default: nil
  attr :company, :string, default: nil
  attr :notes, :string, default: nil
  attr :matomes, :list, default: []
  attr :spaces, :list, default: []
  attr :files, :list, default: []

  def contact_detail(assigns) do
    ~H"""
    <div class="matome-contact-detail">
      <div class="matome-contact-detail__header">
        <.avatar initials={initials(@name)} size="lg" />
        <div class="matome-contact-detail__identity">
          <div class="matome-contact-detail__name">{@name}</div>
          <div :if={@subtitle} class="matome-contact-detail__subtitle">{@subtitle}</div>
          <.sync_chip state={@sync} />
        </div>
        <.icon_button name="more_horiz" label="Contact actions" />
      </div>

      <div class="matome-contact-detail__body">
        <div class="matome-contact-detail__col matome-contact-detail__col--identity">
          <.panel_section label="Contact info">
            <.info_row :if={@email} icon="mail" label="Email" value={@email} />
            <.info_row :if={@phone} icon="phone" label="Phone" value={@phone} />
            <.info_row :if={@company} icon="business" label="Company" value={@company} />
            <div :if={!@email && !@phone && !@company} class="matome-muted-line">Add info</div>
          </.panel_section>
          <.panel_section label="Notes" show_divider={false}>
            <:action><.text_button>Edit</.text_button></:action>
            <div :if={@notes} class="matome-detail-panel__notes">{@notes}</div>
            <div :if={!@notes} class="matome-muted-line">No notes yet</div>
          </.panel_section>
        </div>

        <div class="matome-contact-detail__col matome-contact-detail__col--relations">
          <.panel_section label={"Matomes · #{length(@matomes)}"}>
            <.panel_row :for={m <- @matomes} icon="workspaces" title={m.title} meta={m[:when]}>
              <:trailing><.role_chip role={m.role} /></:trailing>
            </.panel_row>
            <div :if={@matomes == []} class="matome-muted-line">No matomes yet</div>
          </.panel_section>
          <.panel_section label={"Spaces · #{length(@spaces)}"}>
            <div :if={@spaces != []} class="matome-relation-wrap">
              <.space_chip :for={s <- @spaces} space={s} />
            </div>
            <div :if={@spaces == []} class="matome-muted-line">No spaces yet</div>
          </.panel_section>
          <.panel_section label={"Files · #{length(@files)}"} show_divider={false}>
            <.panel_row :for={f <- @files} icon={file_kind_icon(f.kind)} title={f.name} />
            <div :if={@files == []} class="matome-muted-line">No files yet</div>
          </.panel_section>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Icon + uppercase label + value info row (Flutter `_InfoRow`).
  """
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  def info_row(assigns) do
    ~H"""
    <div class="matome-info-row">
      <span class="matome-info-row__icon"><.icon name={@icon} /></span>
      <div>
        <div class="matome-info-row__label">{@label}</div>
        <div class="matome-info-row__value">{@value}</div>
      </div>
    </div>
    """
  end

  # ─── File card (FilesGrid tile) ─────────────────────────────────────────────

  @doc """
  Files grid tile (Flutter `FilesGrid` `_FileTile`, graduated proposal).

  A kind-tinted preview (with an optional audio `duration` tag) over a footer
  of name, size · when, and the `matome_chip/1` + `sync_chip/1` /
  `space_chip/1` + `people_cluster/1` relation rows.
  """
  attr :name, :string, required: true
  attr :kind, :string, default: "document", values: ~w(audio image document video)
  attr :at, :string, default: nil, doc: "display timestamp"
  attr :size, :string, default: nil
  attr :duration, :string, default: nil
  attr :matome, :string, default: nil
  attr :space, :string, default: nil
  attr :people, :list, default: []
  attr :sync, :string, default: "cloud"
  attr :selected, :boolean, default: false

  def file_card(assigns) do
    ~H"""
    <div class={["matome-file-card", @selected && "matome-file-card--selected"]}>
      <div class={["matome-file-card__preview", "matome-file-card__preview--#{@kind}"]}>
        <.icon name={file_kind_icon(@kind)} />
        <span :if={@duration} class="matome-file-card__duration">{@duration}</span>
      </div>
      <div class="matome-file-card__footer">
        <div class="matome-file-card__name">{@name}</div>
        <div class="matome-file-card__sub">
          <span>{@size || "—"}</span><span>·</span><span>{@at}</span>
        </div>
        <div class="matome-file-card__relrow">
          <.matome_chip matome={@matome} />
          <.sync_chip state={@sync} />
        </div>
        <div class="matome-file-card__relrow">
          <.space_chip space={@space} />
          <.people_cluster :if={@people != []} names={@people} />
        </div>
      </div>
    </div>
    """
  end

  # ─── Helpers ────────────────────────────────────────────────────────────────

  @doc false
  def default_row_id(row) when is_map(row), do: Map.get(row, :id)
  def default_row_id(row), do: row

  defp cell_class(col) do
    width = col[:width]
    base = if width in [nil, "flex"], do: "matome-table__cell--flex", else: "matome-table__cell--#{width}"
    [base, col[:align] == "center" && "matome-table__cell--center"]
  end

  defp sort_icon(true, "asc"), do: "arrow_upward"
  defp sort_icon(true, "desc"), do: "arrow_downward"
  defp sort_icon(_active, _dir), do: "unfold_more"

  defp avatar_state_class("done"), do: "matome-card__avatar--done"
  defp avatar_state_class("failed"), do: "matome-card__avatar--failed"
  defp avatar_state_class(_other), do: nil

  defp media_icon("image"), do: "image"
  defp media_icon("video"), do: "video"
  defp media_icon("document"), do: "description"
  defp media_icon(_audio), do: "play"

  defp matome_item_icon("image"), do: "image"
  defp matome_item_icon("video"), do: "video"
  defp matome_item_icon("document"), do: "description"
  defp matome_item_icon("meeting"), do: "description"
  defp matome_item_icon("text"), do: "description"
  defp matome_item_icon(_audio), do: "mic"

  defp file_kind_icon("audio"), do: "mic"
  defp file_kind_icon("image"), do: "image"
  defp file_kind_icon("video"), do: "video"
  defp file_kind_icon(_document), do: "description"

  defp inbox?(space), do: space in [nil, ""]

  defp swatch_style(color) do
    var = "var(--matome-space-#{color})"
    "background:color-mix(in srgb, #{var} 13%, transparent);color:#{var}"
  end

  defp initials(nil), do: "?"

  defp initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end
end

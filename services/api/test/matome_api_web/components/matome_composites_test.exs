defmodule MatomeApiWeb.MatomeCompositesTest do
  @moduledoc """
  Dead-render assertions for the W2 composite-tier components (#1870).

  Like the W1 base-component suite, these render each composite's HEEx to a
  string via `Phoenix.HTML.Safe` and assert the token-driven classes/markup for
  each variant. This avoids the `lazy_html` C-NIF that connected-socket /
  `render_component` tests need — it cannot be built in this offline env (see
  W0 #1868). Each composite is exercised through its real call site (default
  attrs applied), and the assertions confirm it composes the W1 base atoms.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  alias MatomeApiWeb.MatomeComponents
  alias MatomeApiWeb.MatomeComposites

  defp html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  test "data_table: header sort state, selection, bulk bar, and rows" do
    assigns = %{
      rows: [
        %{id: "r1", title: "Weekly sync", summary: "Notes", when: "Mon"},
        %{id: "r2", title: "Design review", summary: nil, when: "Tue"}
      ]
    }

    rendered =
      html(~H"""
      <MatomeComposites.data_table
        rows={@rows}
        selectable
        selected={["r1"]}
        active_id="r2"
        sort_key="when"
        sort_dir="desc"
      >
        <:col :let={row} label="Title" sortable sort_key="title">
          <MatomeComposites.table_primary_cell title={row.title} summary={row.summary} />
        </:col>
        <:col :let={row} label="When" width="when" align="center" sortable sort_key="when">
          {row.when}
        </:col>
        <:bulk_actions>
          <MatomeComponents.text_button icon="archive">Archive</MatomeComponents.text_button>
        </:bulk_actions>
      </MatomeComposites.data_table>
      """)

    assert rendered =~ "matome-table"
    # Bulk bar shows the selected count + its slot action (built from a W1 atom).
    assert rendered =~ "matome-table__bulkbar"
    assert rendered =~ "1 selected"
    assert rendered =~ "matome-btn--text"
    # Sort is active on the "when" column (icon glyph is inline SVG, so we assert
    # the active class + the presence of a sort control rather than a name).
    assert rendered =~ "matome-table__sort--active"
    assert rendered =~ "matome-table__sort-icon"
    # Selected + active row modifiers.
    assert rendered =~ "matome-table__row--selected"
    assert rendered =~ "matome-table__row--active"
    # Primary cell renders title + a filled/empty summary.
    assert rendered =~ "Weekly sync"
    assert rendered =~ "matome-table__summary--empty"
    # Selection column reuses the W1 checkbox atom class.
    assert rendered =~ "matome-checkbox__box"
  end

  test "data_table: empty rows render the base empty_state" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComposites.data_table rows={[]} empty_title="No sessions">
        <:col label="Title">x</:col>
      </MatomeComposites.data_table>
      """)

    assert rendered =~ "matome-empty"
    assert rendered =~ "No sessions"
  end

  test "table_count renders a token or a dash" do
    assigns = %{}

    assert html(~H"""
           <MatomeComposites.table_count icon="mic" count={3} />
           """) =~ "matome-table__count"

    assert html(~H"""
           <MatomeComposites.table_count icon="mic" count={0} />
           """) =~ "matome-table__dash"
  end

  test "nav_sidebar: destinations, active tint, account avatar; collapsed modifier" do
    assigns = %{
      dests: [
        %{id: "inbox", icon: "inbox", label: "Inbox"},
        %{id: "files", icon: "folder", label: "Files"}
      ]
    }

    expanded =
      html(~H"""
      <MatomeComposites.nav_sidebar destinations={@dests} active_id="files" account_name="Ana Ribeiro" />
      """)

    assert expanded =~ "matome-sidebar"
    refute expanded =~ "matome-sidebar--collapsed"
    assert expanded =~ "matome-nav-item--active"
    assert expanded =~ "Files"
    # Account footer reuses the W1 avatar atom (initials AR).
    assert expanded =~ "matome-avatar"
    assert expanded =~ "AR"

    collapsed =
      html(~H"""
      <MatomeComposites.nav_sidebar destinations={@dests} collapsed />
      """)

    assert collapsed =~ "matome-sidebar--collapsed"
    assert collapsed =~ "matome-nav-add--tile"
  end

  test "nav_dock: icon-only items with active tint + settings avatar" do
    assigns = %{
      dests: [
        %{id: "inbox", icon: "inbox", label: "Inbox"},
        %{id: "calendar", icon: "schedule", label: "Calendar"}
      ]
    }

    rendered =
      html(~H"""
      <MatomeComposites.nav_dock destinations={@dests} active_id="inbox" account_name="Leo" />
      """)

    assert rendered =~ "matome-dock"
    assert rendered =~ "matome-dock__item--active"
    assert rendered =~ ~s(aria-label="Calendar")
    assert rendered =~ "matome-avatar"
  end

  test "nav_fab renders an accent add button" do
    assigns = %{}

    assert html(~H"""
           <MatomeComposites.nav_fab />
           """) =~ "matome-fab"
  end

  test "master_detail: detail slot wins over empty; close bar toggles" do
    assigns = %{}

    with_detail =
      html(~H"""
      <MatomeComposites.master_detail show_close>
        <:master>MASTER</:master>
        <:detail>DETAIL</:detail>
        <:empty>EMPTY</:empty>
      </MatomeComposites.master_detail>
      """)

    assert with_detail =~ "matome-masterdetail"
    assert with_detail =~ "matome-masterdetail__closebar"
    assert with_detail =~ "DETAIL"
    refute with_detail =~ "EMPTY"

    empty =
      html(~H"""
      <MatomeComposites.master_detail>
        <:master>MASTER</:master>
        <:empty>EMPTY</:empty>
      </MatomeComposites.master_detail>
      """)

    assert empty =~ "EMPTY"
    refute empty =~ "matome-masterdetail__closebar"
  end

  test "list_row: leading icon, tag, meta, footer slot" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComposites.list_row icon="mic" title="Standup audio" meta="14:30 · 03:12" tag="Loose">
        <:footer>
          <MatomeComponents.sync_chip state="on_device" />
        </:footer>
      </MatomeComposites.list_row>
      """)

    assert rendered =~ "matome-list-row"
    assert rendered =~ "Standup audio"
    assert rendered =~ "matome-kind-tag"
    assert rendered =~ "Loose"
    # Footer composes the W1 sync chip.
    assert rendered =~ "matome-sync-chip--on-device"
  end

  test "contact_tile: swatch is token-driven, notes optional" do
    assigns = %{}

    with_notes =
      html(~H"""
      <MatomeComposites.contact_tile name="Ana Ribeiro" notes="Design lead" color="blue" />
      """)

    assert with_notes =~ "matome-contact-tile"
    assert with_notes =~ "Ana Ribeiro"
    assert with_notes =~ "Design lead"
    # Swatch tint references the spaces-band token (no hardcoded color).
    assert with_notes =~ "var(--matome-space-blue)"

    bare =
      html(~H"""
      <MatomeComposites.contact_tile name="Leo" />
      """)

    refute bare =~ "matome-contact-tile__notes"
  end

  test "app_card matome: summary fallback + meta slot + trailing" do
    assigns = %{}

    filled =
      html(~H"""
      <MatomeComposites.app_card variant="matome" title="Client X — weekly" summary="Recap">
        <:meta>
          <MatomeComposites.meta_token icon="mic" label="2" />
          <MatomeComposites.place_chip space="Marketing" />
          <MatomeComponents.sync_chip state="cloud" />
        </:meta>
      </MatomeComposites.app_card>
      """)

    assert filled =~ "matome-card"
    assert filled =~ "Recap"
    assert filled =~ "matome-place-chip"
    assert filled =~ "Marketing"
    assert filled =~ "matome-sync-chip--cloud"

    empty =
      html(~H"""
      <MatomeComposites.app_card variant="matome" title="Untitled" />
      """)

    assert empty =~ "matome-card__summary--empty"
    assert empty =~ "No summary yet"
  end

  test "app_card calendar: badge dot + status badge + chevron" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComposites.app_card
        variant="calendar"
        title="Team standup"
        badge="work"
        badge_label="Work"
        duration="30m"
      />
      """)

    assert rendered =~ "matome-card--calendar"
    assert rendered =~ "matome-card__dot--work"
    # Composes the W1 status badge atom.
    assert rendered =~ "matome-badge--work"
    assert rendered =~ "30m"
  end

  test "app_card recording states: processing spinner and failed retry" do
    assigns = %{}

    processing =
      html(~H"""
      <MatomeComposites.app_card variant="recording" title="Meeting" state="processing" />
      """)

    assert processing =~ "matome-card__avatar"
    # Processing composes the W1 loading indicator.
    assert processing =~ "matome-spinner"
    assert processing =~ "Processing"

    failed =
      html(~H"""
      <MatomeComposites.app_card
        variant="recording"
        title="Meeting"
        state="failed"
        status_label="Failed"
        status_tone="default"
      />
      """)

    assert failed =~ "matome-card__avatar--failed"
    assert failed =~ "Upload failed"
    # Retry is a W1 text button.
    assert failed =~ "matome-btn--text"

    done =
      html(~H"""
      <MatomeComposites.app_card variant="recording" title="Meeting" state="done" sync="cloud" duration="12:04" />
      """)

    assert done =~ "matome-card__avatar--done"
    assert done =~ "matome-sync-chip--cloud"
    assert done =~ "12:04"
  end

  test "detail_panel: fixed IA sections built from panel atoms; inbox vs filed" do
    assigns = %{
      items: [
        %{media: "audio", title: "Meeting audio", meta: "12:04", sync: "cloud"},
        %{media: "image", title: "Whiteboard", meta: nil, sync: "on_device"}
      ],
      contacts: [%{initial: "A", name: "Ana", role: "Organizer"}]
    }

    filed =
      html(~H"""
      <MatomeComposites.detail_panel
        title="Client X — weekly"
        items={@items}
        contacts={@contacts}
        space_name="Marketing"
        notes="Discussed Q3."
      />
      """)

    assert filed =~ "matome-detail-panel"
    assert filed =~ "matome-detail-panel__title"
    # Sections + rows are the W1 panel atoms.
    assert filed =~ "matome-panel-section"
    assert filed =~ "Items · 2"
    assert filed =~ "People · 1"
    assert filed =~ "matome-panel-row__title"
    assert filed =~ "Meeting audio"
    # Item trailing = W1 sync chip; person leading = W1 avatar.
    assert filed =~ "matome-sync-chip"
    assert filed =~ "matome-avatar"
    # Add rows for items + people.
    assert filed =~ "matome-panel-add"
    # Filed space shows the space name + a refile text button, not the inbox affordance.
    assert filed =~ "Marketing"

    inbox =
      html(~H"""
      <MatomeComposites.detail_panel title="Loose note" items={[]} contacts={[]} />
      """)

    assert inbox =~ "File into space"
  end

  test "contact_detail: header sync chip, info rows, role + space chips" do
    assigns = %{
      matomes: [%{title: "Client X sync", role: "organizer", when: "Mon"}],
      spaces: ["Marketing", "Ops"],
      files: [%{name: "brief.pdf", kind: "document"}]
    }

    rendered =
      html(~H"""
      <MatomeComposites.contact_detail
        name="Ana Ribeiro"
        subtitle="Design lead · Acme"
        sync="cloud"
        email="ana@acme.co"
        phone="+1 555 0100"
        company="Acme"
        notes="Prefers async."
        matomes={@matomes}
        spaces={@spaces}
        files={@files}
      />
      """)

    assert rendered =~ "matome-contact-detail"
    assert rendered =~ "Ana Ribeiro"
    # Header avatar (AR) + sync chip.
    assert rendered =~ "matome-avatar"
    assert rendered =~ "matome-sync-chip--cloud"
    # Info rows.
    assert rendered =~ "matome-info-row"
    assert rendered =~ "ana@acme.co"
    # Relations: role chip + space chips.
    assert rendered =~ "matome-role-chip--organizer"
    assert rendered =~ "matome-chip--space"
    assert rendered =~ "Marketing"
    assert rendered =~ "Files · 1"
  end

  test "contact_detail: sparse contact shows muted placeholders" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComposites.contact_detail name="Leo" />
      """)

    assert rendered =~ "matome-muted-line"
    assert rendered =~ "Add info"
    assert rendered =~ "No matomes yet"
  end

  test "file_card: kind preview, relation chips, duration, selection" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComposites.file_card
        name="standup.m4a"
        kind="audio"
        at="Mon"
        size="4.2 MB"
        duration="03:12"
        matome="Client X"
        space="Marketing"
        people={["Ana", "Ken"]}
        sync="syncing"
        selected
      />
      """)

    assert rendered =~ "matome-file-card"
    assert rendered =~ "matome-file-card--selected"
    assert rendered =~ "matome-file-card__preview--audio"
    assert rendered =~ "standup.m4a"
    assert rendered =~ "matome-file-card__duration"
    assert rendered =~ "03:12"
    # Relation atoms: matome chip (filled), sync chip, space chip, people cluster.
    assert rendered =~ "matome-chip--matome"
    assert rendered =~ "matome-sync-chip--syncing"
    assert rendered =~ "matome-chip--space"
    assert rendered =~ "matome-cluster"

    unfiled =
      html(~H"""
      <MatomeComposites.file_card name="memo.txt" kind="document" />
      """)

    # Nil matome/space fall back to the W1 empty-chip states.
    assert unfiled =~ "matome-chip--empty"
  end
end

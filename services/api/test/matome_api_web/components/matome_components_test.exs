defmodule MatomeApiWeb.MatomeComponentsTest do
  @moduledoc """
  Dead-render assertions for the W1 base-tier components (#1869).

  These render each component's HEEx to a string via `Phoenix.HTML.Safe` and
  assert the token-driven classes/markup for each variant. This avoids the
  `lazy_html` C-NIF that connected-socket / `render_component` tests need — it
  cannot be built in this offline env (see mix.exs and W0 #1868). Because attr
  defaults are applied at the component call site, the tags below exercise the
  real default handling, not a hand-built assigns map.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  alias MatomeApiWeb.MatomeComponents

  # Render a ~H `%Rendered{}` (which implements Phoenix.HTML.Safe) to a string.
  defp html(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  test "primary_button: default, icon, and disabled variants" do
    assigns = %{}

    default =
      html(~H"""
      <MatomeComponents.primary_button>Save</MatomeComponents.primary_button>
      """)

    assert default =~ "matome-btn matome-btn--primary"
    assert default =~ "Save"
    refute default =~ "disabled"

    disabled =
      html(~H"""
      <MatomeComponents.primary_button disabled icon="add">Add</MatomeComponents.primary_button>
      """)

    assert disabled =~ "disabled"
    assert disabled =~ "matome-icon"
  end

  test "text_button and icon_button render token classes" do
    assigns = %{}

    text =
      html(~H"""
      <MatomeComponents.text_button>Cancel</MatomeComponents.text_button>
      """)

    assert text =~ "matome-btn--text"

    icon =
      html(~H"""
      <MatomeComponents.icon_button name="close" label="Close" />
      """)

    assert icon =~ "matome-icon-btn"
    assert icon =~ ~s(aria-label="Close")
  end

  test "submit_button swaps label for a spinner when loading" do
    assigns = %{}

    idle =
      html(~H"""
      <MatomeComponents.submit_button>Sign in</MatomeComponents.submit_button>
      """)

    assert idle =~ "Sign in"
    refute idle =~ "matome-spinner"

    loading =
      html(~H"""
      <MatomeComponents.submit_button loading>Sign in</MatomeComponents.submit_button>
      """)

    assert loading =~ "matome-spinner"
    assert loading =~ "disabled"
    refute loading =~ "Sign in"
  end

  test "text_field: label, hint, type, obscure, disabled" do
    assigns = %{}

    field =
      html(~H"""
      <MatomeComponents.text_field label="Email" hint="you@example.com" name="email" />
      """)

    assert field =~ "matome-field__label"
    assert field =~ "Email"
    assert field =~ ~s(placeholder="you@example.com")
    assert field =~ ~s(type="text")

    email =
      html(~H"""
      <MatomeComponents.text_field label="Email" type="email" name="email" />
      """)

    assert email =~ ~s(type="email")

    secret =
      html(~H"""
      <MatomeComponents.text_field label="Password" obscure disabled />
      """)

    assert secret =~ ~s(type="password")
    assert secret =~ "disabled"
  end

  test "select renders options and marks the selected value" do
    assigns = %{opts: [{"Work", "work"}, {"Personal", "personal"}]}

    rendered =
      html(~H"""
      <MatomeComponents.select label="Space" options={@opts} value="personal" />
      """)

    assert rendered =~ "matome-field__control"
    assert rendered =~ ~s(value="work")
    assert rendered =~ "Personal"
    assert rendered =~ "selected"
  end

  test "checkbox reflects checked state" do
    assigns = %{}

    off =
      html(~H"""
      <MatomeComponents.checkbox>Agree</MatomeComponents.checkbox>
      """)

    assert off =~ "matome-checkbox"
    refute off =~ "checked"

    on =
      html(~H"""
      <MatomeComponents.checkbox checked>Agree</MatomeComponents.checkbox>
      """)

    assert on =~ "checked"
  end

  test "empty_state renders icon slot and optional message" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComponents.empty_state title="Nothing here" message="Add your first item.">
        <:icon>*</:icon>
      </MatomeComponents.empty_state>
      """)

    assert rendered =~ "matome-empty"
    assert rendered =~ "Nothing here"
    assert rendered =~ "Add your first item."
  end

  test "loading_indicator sizes" do
    assigns = %{}

    assert html(~H"""
           <MatomeComponents.loading_indicator size="lg" />
           """) =~ "matome-spinner--lg"

    assert html(~H"""
           <MatomeComponents.loading_indicator />
           """) =~ "matome-spinner--md"
  end

  test "banners carry role + tone" do
    assigns = %{}

    err =
      html(~H"""
      <MatomeComponents.error_banner message="Invalid credentials" />
      """)

    assert err =~ "matome-banner--error"
    assert err =~ ~s(role="alert")
    assert err =~ "Invalid credentials"

    notice =
      html(~H"""
      <MatomeComponents.notice_banner message="Reset link sent" />
      """)

    assert notice =~ "matome-banner--notice"
    assert notice =~ "Reset link sent"
  end

  test "avatar renders initials or icon by size" do
    assigns = %{}

    initials =
      html(~H"""
      <MatomeComponents.avatar initials="AK" size="lg" />
      """)

    assert initials =~ "matome-avatar--lg"
    assert initials =~ "AK"

    icon =
      html(~H"""
      <MatomeComponents.avatar icon="person" />
      """)

    assert icon =~ "matome-avatar--md"
    assert icon =~ "matome-icon"
  end

  test "people_cluster shows overflow count" do
    assigns = %{names: ~w(Leo Ana Ken Mika Yui)}

    rendered =
      html(~H"""
      <MatomeComponents.people_cluster names={@names} />
      """)

    assert rendered =~ "matome-cluster"
    assert rendered =~ "matome-cluster__overflow"
    assert rendered =~ "+2"
  end

  test "status_badge tones" do
    assigns = %{}

    work =
      html(~H"""
      <MatomeComponents.status_badge label="Work" tone="work" />
      """)

    assert work =~ "matome-badge--work"
    assert work =~ "matome-badge__dot"
    assert work =~ "Work"
  end

  test "sync_chip states map to labels and modifiers" do
    assigns = %{}

    assert html(~H"""
           <MatomeComponents.sync_chip state="cloud" />
           """) =~ "matome-sync-chip--cloud"

    on_device =
      html(~H"""
      <MatomeComponents.sync_chip state="on_device" />
      """)

    assert on_device =~ "matome-sync-chip--on-device"
    assert on_device =~ "On device"
  end

  test "matome_chip and space_chip filed vs empty states" do
    assigns = %{}

    filed =
      html(~H"""
      <MatomeComponents.matome_chip matome="Client X" />
      """)

    assert filed =~ "matome-chip--matome"
    refute filed =~ "matome-chip--empty"
    assert filed =~ "Client X"

    unfiled =
      html(~H"""
      <MatomeComponents.matome_chip />
      """)

    assert unfiled =~ "matome-chip--empty"
    assert unfiled =~ "Unfiled"

    inbox =
      html(~H"""
      <MatomeComponents.space_chip />
      """)

    assert inbox =~ "matome-chip--space"
    assert inbox =~ "matome-chip--empty"
    assert inbox =~ "Inbox"
  end

  test "role_chip tints by role" do
    assigns = %{}

    org =
      html(~H"""
      <MatomeComponents.role_chip role="organizer" />
      """)

    assert org =~ "matome-role-chip--organizer"
    assert org =~ "Organizer"
  end

  test "file_type_chip renders name, size, and disabled open affordance" do
    assigns = %{}

    rendered =
      html(~H"""
      <MatomeComponents.file_type_chip file_name="Q3 roadmap.pdf" size_label="2.4 MB" />
      """)

    assert rendered =~ "matome-file-chip"
    assert rendered =~ "Q3 roadmap.pdf"
    assert rendered =~ "2.4 MB"
    assert rendered =~ "matome-file-chip__soon"
    # The Open button is disabled (preview deferred).
    assert rendered =~ "disabled"
  end

  test "panel atoms: section, row, add row" do
    assigns = %{}

    section =
      html(~H"""
      <MatomeComponents.panel_section label="Items · 2">
        <:action>Edit</:action>
        <MatomeComponents.panel_row icon="file" title="Meeting audio" meta="14:30 · 12:04">
          <:trailing><MatomeComponents.sync_chip state="cloud" /></:trailing>
        </MatomeComponents.panel_row>
      </MatomeComponents.panel_section>
      """)

    assert section =~ "matome-panel-section"
    assert section =~ "Items · 2"
    assert section =~ "matome-panel-section__action"
    assert section =~ "matome-panel-row__title"
    assert section =~ "Meeting audio"
    assert section =~ "matome-panel-section__divider"

    add =
      html(~H"""
      <MatomeComponents.panel_add_row label="Add item" />
      """)

    assert add =~ "matome-panel-add"
    assert add =~ "Add item"
  end
end

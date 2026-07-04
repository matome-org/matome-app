defmodule MatomeApiWeb.AdminLiveTest do
  @moduledoc """
  Wave 0 (#1868) acceptance: the /admin empty shell renders under the
  LiveView socket. Proves the LiveView pipeline, root/app layouts, and asset
  references are wired without any data views.
  """
  use MatomeApiWeb.ConnCase

  # NOTE: the connected `live/2` socket assertion needs the `lazy_html` test
  # dep (a C-NIF unavailable in this offline wave). The dead-render GET below
  # already exercises the LiveView mount + render + layouts + asset wiring
  # through the endpoint pipeline; add the `live/2` mount test once lazy_html
  # is fetchable. (W0 #1868)

  test "GET /admin dead-renders the empty admin shell via the LiveView", %{conn: conn} do
    conn = get(conn, "/admin")
    html = html_response(conn, 200)

    # Root layout wired the compiled asset bundle + csrf token.
    assert html =~ ~s(<meta name="csrf-token")
    assert html =~ "/assets/app.css"
    assert html =~ "/assets/app.js"
    # The AdminLive.Index empty-shell content rendered.
    assert html =~ "Admin shell"
    assert html =~ "matome · back-office"
  end
end

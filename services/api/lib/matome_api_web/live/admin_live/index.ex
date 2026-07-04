defmodule MatomeApiWeb.AdminLive.Index do
  @moduledoc """
  The /admin back-office root — an EMPTY shell for Wave 0 (#1868).

  It exists to prove the LiveView socket, asset pipeline, and foundations
  theme are wired end to end. No data views live here yet; later waves of
  the p2-core-backoffice plan hang the real admin surfaces off this mount.
  """
  use MatomeApiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="admin-empty">
      <p class="admin-empty__eyebrow">matome · back-office</p>
      <h1 class="admin-empty__title">Admin shell</h1>
      <p class="admin-empty__body">
        Wave 0 scaffold. LiveView socket, esbuild + Tailwind pipeline, and the
        foundations design tokens are wired. Data views arrive in later waves.
      </p>
    </section>
    """
  end
end

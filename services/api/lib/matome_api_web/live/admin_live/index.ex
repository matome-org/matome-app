defmodule MatomeApiWeb.AdminLive.Index do
  @moduledoc """
  The /admin back-office root (W0 shell, W7 nav).

  Landing page behind the W3 gate with links to the Sessions / Users /
  Audit LiveViews. Still metadata-only — no DEK, FEKs, or user content.
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
      <h1 class="admin-empty__title">Admin</h1>
      <p class="admin-empty__body">
        Staff-only surfaces behind the W3 gate. Zero-knowledge safe: metadata
        only — no DEK, FEKs, or user content.
      </p>
      <nav class="admin-empty__nav" aria-label="Admin views">
        <a href="/admin/sessions">Sessions</a>
        <a href="/admin/users">Users</a>
        <a href="/admin/audit">Audit log</a>
      </nav>
    </section>
    """
  end
end

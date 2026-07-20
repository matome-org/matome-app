defmodule MatomeApiWeb.AdminLive.Index do
  @moduledoc """
  The /admin back-office landing dashboard.

  Metadata-only KPIs and charts (users/devices activity, platforms, space
  storage). Zero-knowledge safe — no DEK, FEKs, or user content.
  """
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.AdminLive.Charts

  alias MatomeApi.Admin

  @refresh_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh_stats, @refresh_ms)

    {:ok,
     socket
     |> assign(page_title: "Admin")
     |> assign_stats()}
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    Process.send_after(self(), :refresh_stats, @refresh_ms)
    {:noreply, assign_stats(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="admin-dashboard">
      <header class="admin-dashboard__header">
        <p class="admin-dashboard__eyebrow">matome · back-office</p>
        <h1 class="admin-dashboard__title">Admin</h1>
        <p class="admin-dashboard__lede">
          Staff-only surfaces. Metadata only — no DEK, FEKs, or user content.
          Storage sizes are client-declared blob metadata.
        </p>
        <nav class="admin-dashboard__nav" aria-label="Admin views">
          <a href="/admin/sessions">Sessions</a>
          <a href="/admin/users">Users</a>
          <a href="/admin/spaces">Spaces</a>
          <a href="/admin/audit">Audit log</a>
          <a href="/admin/events">Events</a>
          <a href="/admin/work">Work</a>
          <a href="/admin/event-catalog">Event catalog</a>
          <a href="/admin/settings">Settings</a>
        </nav>
      </header>

      <div class="admin-dashboard__kpis" role="group" aria-label="Key metrics">
        <div class="admin-kpi">
          <span class="admin-kpi__label">Total users</span>
          <span class="admin-kpi__value">{@stats.users.total}</span>
        </div>
        <div class="admin-kpi">
          <span class="admin-kpi__label">Active users</span>
          <span class="admin-kpi__value">{@stats.users.active}</span>
        </div>
        <div class="admin-kpi">
          <span class="admin-kpi__label">Active devices</span>
          <span class="admin-kpi__value">{@stats.devices.active}</span>
        </div>
        <div class="admin-kpi">
          <span class="admin-kpi__label">Total storage</span>
          <span class="admin-kpi__value">{format_gib(@stats.storage.total_bytes)}</span>
        </div>
      </div>

      <div class="admin-dashboard__charts">
        <.donut_chart
          title="Users"
          segments={[
            %{
              label: "Active",
              value: @stats.users.active,
              color: "var(--matome-space-green)"
            },
            %{
              label: "Inactive",
              value: @stats.users.inactive,
              color: "var(--matome-badge-default)"
            }
          ]}
        />
        <.donut_chart
          title="Devices"
          segments={[
            %{
              label: "Active",
              value: @stats.devices.active,
              color: "var(--matome-space-blue)"
            },
            %{
              label: "Inactive",
              value: @stats.devices.inactive,
              color: "var(--matome-badge-default)"
            }
          ]}
        />
        <.bar_chart
          title="Access by form factor"
          rows={Enum.map(@stats.form_factors, &%{label: &1.form_factor, value: &1.count})}
          empty_label="No devices recorded yet."
        />
        <.bar_chart
          title="Access by device"
          rows={Enum.map(@stats.device_classes, &%{label: &1.device_class, value: &1.count})}
          empty_label="No devices recorded yet."
        />
        <.bar_chart
          title="Access by OS"
          rows={Enum.map(@stats.platforms, &%{label: &1.platform, value: &1.count})}
          empty_label="No devices recorded yet."
        />
        <.bar_chart
          title={"Spaces · #{format_gib(@stats.storage.total_bytes)} total"}
          rows={storage_rows(@stats.storage)}
          format={:gib}
          empty_label="No spaces or file blobs yet."
        />
      </div>
    </section>
    """
  end

  defp assign_stats(socket) do
    assign(socket, stats: Admin.dashboard_stats(admin_read_opts(socket)))
  end

  defp admin_read_opts(socket) do
    [actor: socket.assigns.current_admin, remote_ip: socket.assigns.client_ip]
  end

  defp storage_rows(%{by_workspace: workspaces, unfiled_bytes: unfiled}) do
    workspace_rows =
      Enum.map(workspaces, fn row ->
        %{label: row.name, value: row.bytes}
      end)

    if unfiled > 0 do
      workspace_rows ++ [%{label: "Unfiled", value: unfiled, color: "var(--matome-text-muted)"}]
    else
      workspace_rows
    end
  end
end

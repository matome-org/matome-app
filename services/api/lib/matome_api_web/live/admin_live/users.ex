defmodule MatomeApiWeb.AdminLive.Users do
  @moduledoc """
  The §9.6 users directory (W7 #1875): every account with observed login
  methods, MFA (TOTP) enrollment status, and last login — rendered
  read-only on the W2 composite table.

  Surfaces the §9.4 zero-knowledge caveat up front: the admin manages the
  *permission* list, but cannot grant crypto access (no space key). That
  avoids the "silently can't decrypt" mystery ticket when membership
  admin lands in later waves.
  """
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Users")
     |> assign(users: Admin.list_users())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-users">
      <h1 class="admin-users__title">Users</h1>

      <.notice_banner message="Admin manages permission, not crypto access. Adding a member to an encrypted space grants the permission list only — an existing member must still wrap the space key to them. Admins cannot silently become readers of encrypted content (§9.4)." />

      <.empty_state
        :if={@users == []}
        title="No users"
        message="No accounts have been registered yet."
      >
        <:icon><.icon name="inbox" /></:icon>
      </.empty_state>

      <.data_table :if={@users != []} rows={@users} row_id={& &1.user.id}>
        <:col :let={row} label="User">
          <.table_primary_cell title={row.user.email} summary={"role · #{row.user.role}"} />
        </:col>
        <:col :let={row} label="Login methods" width="matome">
          {format_methods(row.login_methods)}
        </:col>
        <:col :let={row} label="MFA" width="sync">
          <.status_badge
            label={if row.mfa_enabled, do: "TOTP on", else: "Off"}
            tone={if row.mfa_enabled, do: "work", else: "default"}
          />
        </:col>
        <:col :let={row} label="Last login" width="when">
          {format_time(row.last_login_at)}
        </:col>
      </.data_table>
    </div>
    """
  end

  defp format_methods([]), do: "—"
  defp format_methods(methods), do: Enum.join(methods, ", ")

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
end

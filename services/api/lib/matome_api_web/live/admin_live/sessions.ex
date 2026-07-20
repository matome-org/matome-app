defmodule MatomeApiWeb.AdminLive.Sessions do
  @moduledoc """
  The §9.2 sessions view (W6 #1874): every active session resolved as
  `user → device → tokens`, rendered on the W2 composite components, with
  audited real-time revocation.

  Live updates ride the existing W5 invalidation broadcast: every revocation
  path already publishes `{:token_allowlist_invalidate, jti}` on the
  `TokenAllowlist.topic()` — this view subscribes and reloads, so a revoke
  from any node/process (logout, password reset, another admin) refreshes
  the table without new broadcast infrastructure.

  "Active now" is DEGRADED to `last_seen_at` recency, deliberately: real
  Presence needs a Flutter-side `user_socket` heartbeat contract that does
  not exist yet (cross-repo gap, recorded in the dod-matrix). Revocation is
  a sensitive action — it re-checks OTP freshness at event time and bounces
  to `/admin/otp` when stale.
  """
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin
  alias MatomeApi.Auth.TokenAllowlist
  alias MatomeApiWeb.AdminAuth

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MatomeApi.PubSub, TokenAllowlist.topic())
    end

    {:ok,
     socket
     |> assign(page_title: "Sessions")
     |> load_sessions()}
  end

  @impl true
  def handle_info({:token_allowlist_invalidate, _jti}, socket) do
    {:noreply, load_sessions(socket)}
  end

  @impl true
  def handle_event("revoke", %{"jti" => jti}, socket) do
    if recent_otp?(socket) do
      case Admin.revoke_session(socket.assigns.current_admin, jti,
             otp_verified_at: socket.assigns.otp_verified_at,
             remote_ip: socket.assigns.client_ip
           ) do
        :ok ->
          {:noreply, socket |> put_flash(:info, "Session revoked.") |> load_sessions()}

        {:error, :not_found} ->
          {:noreply, socket |> put_flash(:error, "Session not found.") |> load_sessions()}

        {:error, :forbidden} ->
          {:noreply, redirect(socket, to: "/admin/login")}

        {:error, :recent_otp_required} ->
          reauthenticate(socket)

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Session revoke failed.")}
      end
    else
      reauthenticate(socket)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-sessions">
      <h1 class="admin-sessions__title">Sessions</h1>

      <.empty_state
        :if={@sessions == []}
        title="No active sessions"
        message="Every session is revoked or expired."
      >
        <:icon><.icon name="inbox" /></:icon>
      </.empty_state>

      <.panel_section :for={entry <- @sessions} label={entry.user.email}>
        <:action>
          <.status_badge
            label={activity_label(entry.last_seen_at, @now)}
            tone={activity_tone(entry.last_seen_at, @now)}
          />
        </:action>

        <div :for={group <- entry.devices} class="admin-sessions__device">
          <.panel_row
            icon="devices"
            title={device_title(group.device)}
            meta={device_meta(group.device)}
          />

          <.data_table rows={group.tokens} row_id={& &1.jti}>
            <:col :let={token} label="Session">
              <.table_primary_cell
                title={token.login_method || "unknown method"}
                summary={"…#{String.slice(token.jti || "", -8, 8)}"}
              />
            </:col>
            <:col :let={token} label="IP" width="space">{token.ip || "—"}</:col>
            <:col :let={token} label="Last seen" width="when">
              {format_time(token.last_seen_at)}
            </:col>
            <:col :let={token} label="Expires" width="when">{format_time(token.expires_at)}</:col>
            <:col :let={token} label="" width="sync">
              <.text_button
                phx-click="revoke"
                phx-value-jti={token.jti}
                data-confirm="Revoke this session? The client is disconnected and must log in again."
              >
                Revoke
              </.text_button>
            </:col>
          </.data_table>
        </div>
      </.panel_section>
    </div>
    """
  end

  defp load_sessions(socket) do
    now = DateTime.utc_now()
    assign(socket, sessions: Admin.session_tree(now, admin_read_opts(socket)), now: now)
  end

  defp recent_otp?(socket) do
    AdminAuth.recent_otp?(%{"admin_otp_verified_at" => socket.assigns.otp_verified_at})
  end

  defp reauthenticate(socket) do
    {:noreply,
     redirect(socket, to: "/admin/otp?return_to=#{URI.encode_www_form("/admin/sessions")}")}
  end

  defp admin_read_opts(socket) do
    [actor: socket.assigns.current_admin, remote_ip: socket.assigns.client_ip]
  end

  defp activity_label(nil, _now), do: "Never seen"

  defp activity_label(last_seen_at, now) do
    if DateTime.diff(now, last_seen_at) < Admin.activity_window_seconds() do
      "Active recently"
    else
      "Last seen #{format_time(last_seen_at)}"
    end
  end

  defp activity_tone(nil, _now), do: "default"

  defp activity_tone(last_seen_at, now) do
    if DateTime.diff(now, last_seen_at) < Admin.activity_window_seconds(),
      do: "work",
      else: "default"
  end

  defp device_title(nil), do: "Unrecognized device"
  defp device_title(device), do: device.display_name || device.platform || "Unnamed device"

  defp device_meta(nil), do: "No device correlation for these tokens"

  defp device_meta(device) do
    [device.platform, device.user_agent]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
end

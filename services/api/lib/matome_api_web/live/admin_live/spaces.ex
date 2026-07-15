defmodule MatomeApiWeb.AdminLive.Spaces do
  @moduledoc """
  §9.4 Spaces admin (W8 #1876): quota, expiry, lifecycle, membership.

  Surfaces the zero-knowledge caveat: membership grants permission only —
  crypto key-share is W9 / space-KEK.
  """
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin
  alias MatomeApiWeb.AdminAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Spaces")
     |> assign(selected_id: nil)
     |> assign(selected: nil)
     |> assign(quota_input: "")
     |> assign(expires_input: "")
     |> assign(member_email: "")
     |> assign(member_role: "member")
     |> assign(flash_note: nil)
     |> assign_spaces()}
  end

  @impl true
  def handle_event("select", %{"id" => id}, socket) do
    selected = Admin.get_space(String.to_integer(id), admin_read_opts(socket))

    {:noreply,
     socket
     |> assign(selected_id: selected && selected.id)
     |> assign(selected: selected)
     |> assign(quota_input: quota_to_input(selected && selected.quota_bytes))
     |> assign(expires_input: expires_to_input(selected && selected.expires_at))
     |> assign(flash_note: nil)}
  end

  def handle_event("save_quota", %{"quota" => quota_raw, "expires" => expires_raw}, socket) do
    with true <- recent_otp?(socket),
         %{} = selected <- socket.assigns.selected,
         {:ok, quota} <- parse_quota(quota_raw),
         {:ok, expires} <- parse_expires(expires_raw),
         {:ok, updated} <-
           Admin.update_space(
             selected.id,
             %{quota_bytes: quota, expires_at: expires},
             mutation_opts(socket)
           ) do
      {:noreply,
       socket
       |> assign(selected: updated)
       |> assign(quota_input: quota_to_input(updated.quota_bytes))
       |> assign(expires_input: expires_to_input(updated.expires_at))
       |> assign(flash_note: "Quota / expiry saved.")
       |> assign_spaces()}
    else
      false ->
        reauthenticate(socket)

      nil ->
        {:noreply, assign(socket, flash_note: "Select a space first.")}

      {:error, reason} ->
        {:noreply, assign(socket, flash_note: "Save failed: #{inspect(reason)}")}
    end
  end

  def handle_event("lifecycle", %{"to" => to_status}, socket) do
    with true <- recent_otp?(socket),
         %{} = selected <- socket.assigns.selected,
         {:ok, updated} <-
           Admin.transition_space(selected.id, to_status, mutation_opts(socket)) do
      {:noreply,
       socket
       |> assign(selected: updated)
       |> assign(flash_note: "Status → #{to_status}")
       |> assign_spaces()}
    else
      false ->
        reauthenticate(socket)

      nil ->
        {:noreply, assign(socket, flash_note: "Select a space first.")}

      {:error, reason} ->
        {:noreply, assign(socket, flash_note: "Transition failed: #{inspect(reason)}")}
    end
  end

  def handle_event("add_member", %{"email" => email, "role" => role}, socket) do
    with true <- recent_otp?(socket),
         %{} = selected <- socket.assigns.selected,
         %MatomeApi.Auth.User{id: user_id} <- find_user_by_email(email),
         {:ok, _member} <-
           Admin.add_space_member(selected.id, user_id, role, mutation_opts(socket)) do
      updated = Admin.get_space(selected.id, admin_read_opts(socket))

      {:noreply,
       socket
       |> assign(selected: updated)
       |> assign(member_email: "")
       |> assign(flash_note: "Member added (permission only — no crypto key).")
       |> assign_spaces()}
    else
      false -> reauthenticate(socket)
      nil -> {:noreply, assign(socket, flash_note: "Select a space first.")}
      :not_found -> {:noreply, assign(socket, flash_note: "User not found.")}
      {:error, reason} -> {:noreply, assign(socket, flash_note: "Add failed: #{inspect(reason)}")}
    end
  end

  def handle_event("revoke_member", %{"id" => member_id}, socket) do
    with true <- recent_otp?(socket),
         %{} = selected <- socket.assigns.selected,
         {:ok, _} <-
           Admin.revoke_space_member(
             String.to_integer(member_id),
             mutation_opts(socket)
           ) do
      updated = Admin.get_space(selected.id, admin_read_opts(socket))

      {:noreply,
       socket
       |> assign(selected: updated)
       |> assign(flash_note: "Membership revoked.")
       |> assign_spaces()}
    else
      false ->
        reauthenticate(socket)

      nil ->
        {:noreply, assign(socket, flash_note: "Select a space first.")}

      {:error, reason} ->
        {:noreply, assign(socket, flash_note: "Revoke failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-spaces">
      <h1 class="admin-spaces__title">Spaces</h1>

      <.notice_banner message="Admin manages permission, not crypto access. Adding a member grants the permission list only — an existing member must still wrap the space key (space-KEK / W9). Admins cannot silently become readers of encrypted content (§9.4)." />

      <p :if={@flash_note} class="admin-spaces__note">{@flash_note}</p>

      <.empty_state
        :if={@spaces == []}
        title="No spaces"
        message="No cloud spaces have been created yet."
      >
        <:icon><.icon name="inbox" /></:icon>
      </.empty_state>

      <.data_table :if={@spaces != []} rows={@spaces} row_id={& &1.workspace.id}>
        <:col :let={row} label="Space">
          <button
            type="button"
            phx-click="select"
            phx-value-id={row.workspace.id}
            class="admin-spaces__select"
          >
            <.table_primary_cell
              title={row.workspace.name}
              summary={"#{row.owner_email} · #{row.workspace.space_type}"}
            />
          </button>
        </:col>
        <:col :let={row} label="Sync" width="sync">
          {if row.workspace.is_local, do: "local", else: "cloud"}
        </:col>
        <:col :let={row} label="Status" width="sync">
          <.status_badge label={row.workspace.status} tone={status_tone(row.workspace.status)} />
        </:col>
        <:col :let={row} label="Quota" width="matome">
          {format_quota(row.workspace.used_bytes, row.workspace.quota_bytes)}
        </:col>
        <:col :let={row} label="Members" width="when">
          {row.member_count}
        </:col>
        <:col :let={row} label="Expires" width="when">
          {format_time(row.workspace.expires_at)}
        </:col>
      </.data_table>

      <section :if={@selected} class="admin-spaces__detail" aria-label="Space detail">
        <h2>{@selected.name}</h2>
        <p>
          Owner {@selected.owner.email} · {@selected.space_type} · {if @selected.is_local,
            do: "local",
            else: "cloud"} · status {@selected.status}
        </p>

        <form phx-submit="save_quota" class="admin-spaces__form">
          <label>
            Quota bytes (blank = unlimited)
            <input type="text" name="quota" value={@quota_input} />
          </label>
          <label>
            Expires at (UTC ISO8601, blank = none)
            <input type="text" name="expires" value={@expires_input} />
          </label>
          <button type="submit">Save quota / expiry</button>
        </form>

        <div class="admin-spaces__lifecycle" role="group" aria-label="Lifecycle">
          <button type="button" phx-click="lifecycle" phx-value-to="suspended">Suspend</button>
          <button type="button" phx-click="lifecycle" phx-value-to="active">Activate</button>
          <button type="button" phx-click="lifecycle" phx-value-to="archived">Archive</button>
          <button type="button" phx-click="lifecycle" phx-value-to="deleted">Delete (grace)</button>
        </div>

        <h3>Members</h3>
        <ul>
          <li :for={m <- active_members(@selected.space_members)}>
            {m.user.email} · {m.role}
            <button type="button" phx-click="revoke_member" phx-value-id={m.id}>Revoke</button>
          </li>
        </ul>

        <form phx-submit="add_member" class="admin-spaces__form">
          <label>
            User email
            <input type="email" name="email" value={@member_email} required />
          </label>
          <label>
            Role
            <select name="role">
              <option value="viewer">viewer</option>
              <option value="member" selected>member</option>
              <option value="admin">admin</option>
              <option value="owner">owner</option>
            </select>
          </label>
          <button type="submit">Add member</button>
        </form>
      </section>
    </div>
    """
  end

  defp assign_spaces(socket),
    do: assign(socket, spaces: Admin.list_spaces(admin_read_opts(socket)))

  defp admin_read_opts(socket) do
    [actor: socket.assigns.current_admin, remote_ip: socket.assigns.client_ip]
  end

  defp mutation_opts(socket) do
    [
      actor: socket.assigns.current_admin,
      otp_verified_at: socket.assigns.otp_verified_at,
      remote_ip: socket.assigns.client_ip
    ]
  end

  defp recent_otp?(socket) do
    AdminAuth.recent_otp?(%{"admin_otp_verified_at" => socket.assigns.otp_verified_at})
  end

  defp reauthenticate(socket) do
    {:noreply,
     redirect(socket, to: "/admin/otp?return_to=#{URI.encode_www_form("/admin/spaces")}")}
  end

  defp active_members(members) when is_list(members),
    do: Enum.reject(members, & &1.revoked_at)

  defp active_members(_), do: []

  defp status_tone("active"), do: "work"
  defp status_tone("suspended"), do: "warn"
  defp status_tone("archived"), do: "default"
  defp status_tone(_), do: "default"

  defp format_quota(used, nil), do: "#{used} / ∞"
  defp format_quota(used, quota), do: "#{used} / #{quota}"

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  defp quota_to_input(nil), do: ""
  defp quota_to_input(n), do: Integer.to_string(n)

  defp expires_to_input(nil), do: ""
  defp expires_to_input(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp parse_quota(""), do: {:ok, nil}
  defp parse_quota(nil), do: {:ok, nil}

  defp parse_quota(raw) when is_binary(raw) do
    case Integer.parse(String.trim(raw)) do
      {n, ""} when n >= 0 -> {:ok, n}
      _ -> {:error, :invalid_quota}
    end
  end

  defp parse_expires(""), do: {:ok, nil}
  defp parse_expires(nil), do: {:ok, nil}

  defp parse_expires(raw) when is_binary(raw) do
    case DateTime.from_iso8601(String.trim(raw)) do
      {:ok, dt, _} -> {:ok, DateTime.truncate(dt, :second)}
      _ -> {:error, :invalid_expires}
    end
  end

  defp find_user_by_email(email) do
    email = String.downcase(String.trim(email))

    case MatomeApi.Repo.get_by(MatomeApi.Auth.User, email: email) do
      nil -> :not_found
      user -> user
    end
  end
end

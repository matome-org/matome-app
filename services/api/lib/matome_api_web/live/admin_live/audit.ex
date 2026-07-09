defmodule MatomeApiWeb.AdminLive.Audit do
  @moduledoc """
  The §9.6 audit-log viewer (W7 #1875): read-only window onto the
  append-only `admin_audit_events` trail populated since W3.

  Filters (admin / action / target / time) are applied in-process via
  `Admin.list_audit_events/1`. The table itself is immutable at the DB
  level — this view never attempts UPDATE/DELETE.
  """
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin
  alias MatomeApi.Auth.User
  alias MatomeApi.Repo

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    filters = empty_filters()

    {:ok,
     socket
     |> assign(page_title: "Audit log")
     |> assign(filters: filters)
     |> assign(admins: list_admins())
     |> load_events(filters)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      actor_id: parse_actor_id(params["actor_id"]),
      action: blank_to_nil(params["action"]),
      target: blank_to_nil(params["target"]),
      since: parse_datetime(params["since"]),
      until: parse_datetime(params["until"])
    }

    {:noreply,
     socket
     |> assign(filters: filters)
     |> load_events(filters)}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    filters = empty_filters()

    {:noreply,
     socket
     |> assign(filters: filters)
     |> load_events(filters)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-audit">
      <h1 class="admin-audit__title">Audit log</h1>
      <p class="admin-audit__lede">
        Append-only trail of admin actions. Rows cannot be edited or deleted.
      </p>

      <form phx-change="filter" phx-submit="filter" class="admin-audit__filters">
        <.select
          name="actor_id"
          label="Admin"
          value={actor_value(@filters.actor_id)}
          options={[{"Any admin", ""} | Enum.map(@admins, &{&1.email, to_string(&1.id)})]}
        />
        <.text_field name="action" label="Action" value={@filters.action || ""} hint="e.g. admin.login" />
        <.text_field
          name="target"
          label="Target"
          value={@filters.target || ""}
          hint="user id, jti, …"
        />
        <.text_field
          name="since"
          label="Since (UTC)"
          value={datetime_value(@filters.since)}
          hint="YYYY-MM-DDTHH:MM"
        />
        <.text_field
          name="until"
          label="Until (UTC)"
          value={datetime_value(@filters.until)}
          hint="YYYY-MM-DDTHH:MM"
        />
        <.text_button type="button" phx-click="clear">Clear</.text_button>
      </form>

      <.empty_state
        :if={@events == []}
        title="No matching events"
        message="Widen the filters or wait for the next admin action."
      >
        <:icon><.icon name="inbox" /></:icon>
      </.empty_state>

      <.data_table :if={@events != []} rows={@events} row_id={& &1.id}>
        <:col :let={event} label="When" width="when">{format_time(event.inserted_at)}</:col>
        <:col :let={event} label="Admin">
          <.table_primary_cell
            title={event.actor_email || "—"}
            summary={if event.actor_id, do: "id #{event.actor_id}", else: "no actor"}
          />
        </:col>
        <:col :let={event} label="Action" width="matome">{event.action}</:col>
        <:col :let={event} label="Target" width="items">{format_target(event.metadata)}</:col>
        <:col :let={event} label="IP" width="space">{event.remote_ip || "—"}</:col>
      </.data_table>
    </div>
    """
  end

  defp load_events(socket, filters) do
    opts =
      [
        actor_id: filters.actor_id,
        action: filters.action,
        target: filters.target,
        since: filters.since,
        until: filters.until
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    assign(socket, events: Admin.list_audit_events(opts))
  end

  defp empty_filters do
    %{actor_id: nil, action: nil, target: nil, since: nil, until: nil}
  end

  defp list_admins do
    from(u in User, where: u.role in ^~w(admin superadmin), order_by: [asc: u.email])
    |> Repo.all()
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp parse_actor_id(nil), do: nil
  defp parse_actor_id(""), do: nil

  defp parse_actor_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        nil

      match?({:ok, %DateTime{}, _}, DateTime.from_iso8601(trimmed)) ->
        {:ok, dt, _} = DateTime.from_iso8601(trimmed)
        DateTime.truncate(dt, :second)

      match?({:ok, %NaiveDateTime{}}, NaiveDateTime.from_iso8601(trimmed)) ->
        {:ok, naive} = NaiveDateTime.from_iso8601(trimmed)
        DateTime.from_naive!(naive, "Etc/UTC")

      match?({:ok, %Date{}}, Date.from_iso8601(trimmed)) ->
        {:ok, date} = Date.from_iso8601(trimmed)
        DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

      true ->
        nil
    end
  end

  defp actor_value(nil), do: ""
  defp actor_value(id), do: to_string(id)

  defp datetime_value(nil), do: ""
  defp datetime_value(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%dT%H:%M")

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  defp format_target(metadata) when metadata == %{}, do: "—"

  defp format_target(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(" · ")
  end
end

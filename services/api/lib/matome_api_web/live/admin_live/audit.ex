defmodule MatomeApiWeb.AdminLive.Audit do
  @moduledoc """
  The §9.6 audit-log viewer: read-only window onto append-only security events.
  Actor filter is by email (email-OTP gate).
  """
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin
  alias MatomeApi.Events.Event
  alias MatomeApi.Admin.NetworkPolicy
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
      actor_email: blank_to_nil(params["actor_email"]),
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
          name="actor_email"
          label="Admin"
          value={@filters.actor_email || ""}
          options={[{"Any admin", ""} | Enum.map(@admins, &{&1, &1})]}
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
        <:col :let={event} label="When" width="when">{format_time(event.occurred_at)}</:col>
        <:col :let={event} label="Admin">
          <.table_primary_cell
            title={event.actor_email || "—"}
            summary={if event.actor_id, do: "id #{event.actor_id}", else: "email OTP"}
          />
        </:col>
        <:col :let={event} label="Action" width="matome">{event.event_key}</:col>
        <:col :let={event} label="Target" width="items">{format_target(event)}</:col>
        <:col :let={event} label="IP" width="space">{event.remote_ip || "—"}</:col>
      </.data_table>
    </div>
    """
  end

  defp load_events(socket, filters) do
    opts =
      [
        actor_email: filters.actor_email,
        action: filters.action,
        target: filters.target,
        since: filters.since,
        until: filters.until
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    assign(socket, events: Admin.list_audit_events(opts))
  end

  defp empty_filters do
    %{actor_email: nil, action: nil, target: nil, since: nil, until: nil}
  end

  defp list_admins do
    from_events =
      from(e in Event,
        where: not is_nil(e.actor_email),
        distinct: true,
        select: e.actor_email,
        order_by: [asc: e.actor_email]
      )
      |> Repo.all()

    (NetworkPolicy.email_allowlist() ++ from_events) |> Enum.uniq() |> Enum.sort()
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
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

  defp datetime_value(nil), do: ""
  defp datetime_value(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%dT%H:%M")

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  defp format_target(%Event{subject_type: type, subject_id: id})
       when is_binary(type) and is_binary(id),
       do: "#{type}=#{id}"

  defp format_target(%Event{details: details}) when details == %{}, do: "—"

  defp format_target(%Event{details: details}) do
    details |> Enum.map(fn {key, value} -> "#{key}=#{value}" end) |> Enum.join(" · ")
  end
end

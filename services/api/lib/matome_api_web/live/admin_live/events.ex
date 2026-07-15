defmodule MatomeApiWeb.AdminLive.Events do
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin

  @page_size 50

  @impl true
  def mount(params, _session, socket) do
    security_view = socket.assigns.live_action == :security
    filters = filters_from_params(params, security_view)

    {:ok,
     socket
     |> assign(page_title: if(security_view, do: "Security events", else: "Events"))
     |> assign(security_view: security_view, filters: filters, cursor: nil)
     |> load_events()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = filters_from_params(params, socket.assigns.security_view)
    {:noreply, socket |> assign(filters: filters, cursor: nil) |> load_events()}
  end

  def handle_event("clear", _params, socket) do
    filters = filters_from_params(%{}, socket.assigns.security_view)
    {:noreply, socket |> assign(filters: filters, cursor: nil) |> load_events()}
  end

  def handle_event("next", _params, %{assigns: %{next_cursor: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("next", _params, socket) do
    {:noreply, socket |> assign(cursor: socket.assigns.next_cursor) |> load_events()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-events">
      <h1 class="admin-events__title">{if @security_view, do: "Security events", else: "Events"}</h1>
      <p class="admin-events__lede">
        <span :if={@security_view}>Security saved view · locked to immutable security rows.</span>
        <span :if={!@security_view}>Unified security, operational, and opted-in product timeline.</span>
      </p>

      <nav class="admin-events__views" aria-label="Event views">
        <a href="/admin/events">All events</a>
        <a href="/admin/events/security">Security saved view</a>
        <a href="/admin/event-catalog">Event catalog</a>
      </nav>

      <form phx-change="filter" phx-submit="filter" class="admin-events__filters">
        <.select
          :if={!@security_view}
          name="event_class"
          label="Class"
          value={@filters.event_class || ""}
          options={[{"Any class", ""}, {"Security", "security"}, {"Operational", "operational"}, {"Product", "product"}]}
        />
        <input :if={@security_view} type="hidden" name="event_class" value="security" />
        <.text_field name="event_key" label="Key" value={@filters.event_key || ""} />
        <.text_field name="actor" label="Actor id / email" value={@filters.actor || ""} />
        <.text_field name="owner_id" label="Owner id" value={integer_value(@filters.owner_id)} />
        <.text_field name="subject_type" label="Subject type" value={@filters.subject_type || ""} />
        <.text_field name="subject_id" label="Subject id" value={@filters.subject_id || ""} />
        <.text_field name="device_id" label="Device id" value={integer_value(@filters.device_id)} />
        <.text_field name="run_id" label="Run id" value={@filters.run_id || ""} />
        <.select
          name="severity"
          label="Severity"
          value={@filters.severity || ""}
          options={[{"Any severity", ""} | Enum.map(~w(info warning error critical), &{&1, &1})]}
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

      <.data_table
        rows={@events}
        row_id={& &1.id}
        empty_title="No matching events"
        empty_message="Widen the filters or wait for the next event."
      >
        <:col :let={event} label="When" width="when">{format_time(event.occurred_at)}</:col>
        <:col :let={event} label="Class" width="sync">
          <.status_badge label={event.event_class} tone={class_tone(event.event_class)} />
        </:col>
        <:col :let={event} label="Key" width="matome">{event.event_key}</:col>
        <:col :let={event} label="Actor">{event.actor_email || id_label(event.actor_id)}</:col>
        <:col :let={event} label="Owner" width="items">{id_label(event.owner_id)}</:col>
        <:col :let={event} label="Subject" width="space">{subject_label(event)}</:col>
        <:col :let={event} label="Device / run" width="space">{device_run_label(event)}</:col>
        <:col :let={event} label="Severity" width="sync">{event.severity}</:col>
      </.data_table>

      <div class="admin-events__pagination">
        <.text_button :if={@next_cursor} type="button" phx-click="next">Next page</.text_button>
      </div>
    </div>
    """
  end

  defp load_events(socket) do
    filters = socket.assigns.filters

    opts =
      [
        limit: @page_size,
        event_class: filters.event_class,
        event_key: filters.event_key,
        actor_id: filters.actor_id,
        actor_email: filters.actor_email,
        owner_id: filters.owner_id,
        subject_type: filters.subject_type,
        subject_id: filters.subject_id,
        device_id: filters.device_id,
        run_id: filters.run_id,
        severity: filters.severity,
        since: filters.since,
        until: filters.until,
        after: socket.assigns.cursor
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    page =
      Admin.list_events(opts,
        actor: socket.assigns.current_admin,
        remote_ip: socket.assigns.client_ip
      )

    assign(socket, events: page.entries, next_cursor: page.next_cursor)
  end

  defp filters_from_params(params, security_view) do
    actor = blank_to_nil(params["actor"])
    actor_id = parse_integer(actor)

    %{
      event_class:
        if(security_view,
          do: "security",
          else: allowed(params["event_class"], ~w(security operational product))
        ),
      event_key: blank_to_nil(params["event_key"]),
      actor: actor,
      actor_id: actor_id,
      actor_email: if(actor && is_nil(actor_id), do: String.downcase(actor)),
      owner_id: parse_integer(params["owner_id"]),
      subject_type: blank_to_nil(params["subject_type"]),
      subject_id: blank_to_nil(params["subject_id"]),
      device_id: parse_integer(params["device_id"]),
      run_id: parse_uuid(params["run_id"]),
      severity: allowed(params["severity"], ~w(info warning error critical)),
      since: parse_datetime(params["since"]),
      until: parse_datetime(params["until"])
    }
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    value
    |> to_string()
    |> String.trim()
    |> then(&if(&1 == "", do: nil, else: &1))
  end

  defp allowed(value, allowed), do: if(value in allowed, do: value)

  defp parse_integer(value) do
    case value && Integer.parse(to_string(value)) do
      {integer, ""} when integer >= 0 -> integer
      _other -> nil
    end
  end

  defp parse_uuid(value) do
    case blank_to_nil(value) do
      nil -> nil
      uuid -> if match?({:ok, _}, Ecto.UUID.cast(uuid)), do: uuid
    end
  end

  defp parse_datetime(value) do
    case blank_to_nil(value) do
      nil ->
        nil

      value ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
          _error -> nil
        end
    end
  end

  defp integer_value(nil), do: ""
  defp integer_value(value), do: to_string(value)
  defp datetime_value(nil), do: ""
  defp datetime_value(value), do: Calendar.strftime(value, "%Y-%m-%dT%H:%M")
  defp format_time(value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M UTC")
  defp id_label(nil), do: "—"
  defp id_label(id), do: to_string(id)
  defp subject_label(%{subject_type: nil}), do: "—"
  defp subject_label(event), do: "#{event.subject_type}=#{event.subject_id}"

  defp device_run_label(event) do
    [event.device_id && "device #{event.device_id}", event.run_id && "run #{event.run_id}"]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> "—"
      labels -> Enum.join(labels, " · ")
    end
  end

  defp class_tone("security"), do: "warn"
  defp class_tone("operational"), do: "work"
  defp class_tone(_class), do: "default"
end

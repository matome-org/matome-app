defmodule MatomeApiWeb.AdminLive.Work do
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.Admin

  @impl true
  def mount(params, _session, socket) do
    filters = filters_from_params(params)

    {:ok,
     socket
     |> assign(page_title: "Work", filters: filters)
     |> load_work(params)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = filters_from_params(params)
    {:noreply, socket |> assign(filters: filters) |> load_work(%{})}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, socket |> assign(filters: filters_from_params(%{})) |> load_work(%{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="admin-work">
      <h1 class="admin-work__title">Work</h1>
      <p class="admin-work__lede">
        <strong>Observation only.</strong> Device snapshots may be delayed or stale.
        No device commands exist, and this view cannot control an offline device.
      </p>

      <form phx-change="filter" phx-submit="filter" class="admin-work__filters">
        <.text_field name="stage" label="Stage" value={@filters.stage || ""} />
        <.text_field name="device" label="Device id" value={value(@filters.device_id)} />
        <.select
          name="media"
          label="Media"
          value={@filters.media || ""}
          options={[{"Any media", ""} | Enum.map(~w(audio image document video text), &{&1, &1})]}
        />
        <.text_field name="error" label="Stable error code" value={@filters.error || ""} />
        <.select
          name="age"
          label="Minimum age"
          value={value(@filters.min_age_seconds)}
          options={[{"Any age", ""}, {"5 minutes", "300"}, {"1 hour", "3600"}, {"24 hours", "86400"}]}
        />
        <.text_button type="button" phx-click="clear">Clear</.text_button>
      </form>

      <h2>Current Core Items</h2>
      <.data_table
        rows={@work.items}
        row_id={& &1.id}
        empty_title="No matching work"
        empty_message="Widen the filters or wait for the next observation."
      >
        <:col :let={item} label="Item">
          <a href={"/admin/work/#{item.id}"}>Item {item.id}</a>
          <span class="admin-work__meta">owner {item.owner_id} · {item.media_type || item.item_type}</span>
        </:col>
        <:col :let={item} label="Stage" width="space">{item.stage}</:col>
        <:col :let={item} label="Upload" width="sync">{item.upload_state || "none"}</:col>
        <:col :let={item} label="Dispatch" width="space">{dispatch_label(item)}</:col>
        <:col :let={item} label="AI terminal" width="space">{terminal_label(item)}</:col>
        <:col :let={item} label="Device" width="space">{device_label(item.device_observation)}</:col>
        <:col :let={item} label="Error" width="space">{item.error_code || "—"}</:col>
      </.data_table>

      <h2>Latest Device Queue Observations</h2>
      <.data_table
        rows={@work.devices}
        row_id={& &1.id}
        empty_title="No device snapshots"
        empty_message="A signed-in Flutter device has not reported a queue observation yet."
      >
        <:col :let={device} label="Device">
          Device {device.id}<span class="admin-work__meta">{device.platform || "unknown platform"}</span>
        </:col>
        <:col :let={device} label="Reported" width="when">{format_time(device.reported_at)}</:col>
        <:col :let={device} label="Queue" width="space">{map_label(device.counts)}</:col>
        <:col :let={device} label="Snapshot" width="space">{snapshot_label(device)}</:col>
        <:col :let={device} label="Config" width="space">{config_label(device)}</:col>
      </.data_table>

      <section :if={@selected} class="admin-work__detail">
        <h2>Item {@selected.id} · run timeline</h2>
        <p>
          {dispatch_label(@selected)}. {terminal_label(@selected)}.
          Oban accepted does not mean AI completed.
        </p>
        <dl class="admin-work__facts">
          <dt>Owner id</dt><dd>{@selected.owner_id}</dd>
          <dt>Run id</dt><dd>{@selected.processing_run_id || "—"}</dd>
          <dt>Upload state</dt><dd>{@selected.upload_state || "none"}</dd>
          <dt>Processing state</dt><dd>{@selected.processing_state}</dd>
          <dt>Logical attempt</dt><dd>{@selected.processing_attempt}</dd>
          <dt>Media</dt><dd>{@selected.media_type || @selected.item_type}</dd>
          <dt>Source revision</dt><dd>{@selected.source_revision}</dd>
          <dt>Config revision</dt><dd>{@selected.processing_config_revision || "—"}</dd>
          <dt>Deadline</dt><dd>{format_time(@selected.processing_deadline_at)}</dd>
          <dt>Device observation</dt><dd>{device_label(@selected.device_observation)}</dd>
        </dl>
        <h3>Events</h3>
        <ol class="admin-work__timeline">
          <li :for={event <- @selected.events}>
            <time>{format_time(event.occurred_at)}</time>
            <strong>{event.event_key}</strong>
            <span>{event.severity}</span>
          </li>
        </ol>
        <p :if={@selected.events == []}>No matching immutable events.</p>
      </section>
    </section>
    """
  end

  defp load_work(socket, params) do
    opts = [actor: socket.assigns.current_admin, remote_ip: socket.assigns.client_ip]
    work = Admin.list_work(socket.assigns.filters, opts)

    selected =
      case parse_integer(params["id"]) do
        nil -> nil
        id -> Admin.get_work_item(id, opts)
      end

    assign(socket, work: work, selected: selected)
  end

  defp filters_from_params(params) do
    %{
      stage: blank_to_nil(params["stage"]),
      device_id: parse_integer(params["device"]),
      media: allowed(params["media"], ~w(audio image document video text)),
      error: blank_to_nil(params["error"]),
      min_age_seconds: parse_integer(params["age"])
    }
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value),
    do: value |> to_string() |> String.trim() |> then(&if(&1 == "", do: nil, else: &1))

  defp allowed(value, allowed), do: if(value in allowed, do: value)

  defp parse_integer(value) do
    case value && Integer.parse(to_string(value)) do
      {integer, ""} when integer >= 0 -> integer
      _invalid -> nil
    end
  end

  defp value(nil), do: ""
  defp value(value), do: to_string(value)
  defp format_time(nil), do: "—"
  defp format_time(value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M UTC")
  defp dispatch_label(%{dispatch: nil}), do: "Not accepted by Oban"
  defp dispatch_label(item), do: "Oban accepted · #{item.dispatch.state}"

  defp terminal_label(%{processing_state: state})
       when state in [:not_available, :succeeded, :partial, :failed],
       do: "AI terminal · #{state}"

  defp terminal_label(item), do: "AI not terminal · #{item.processing_state}"
  defp device_label(nil), do: "No reconciled device observation"

  defp device_label(observation) do
    suffix = if observation.stale, do: " · Stale snapshot", else: " · current snapshot"
    "Device #{observation.device_id}#{suffix}"
  end

  defp snapshot_label(%{stale: true}), do: "Stale snapshot"
  defp snapshot_label(_device), do: "Current snapshot"

  defp config_label(%{config_unacknowledged: true}), do: "Desired config not acknowledged"
  defp config_label(_device), do: "Desired config acknowledged"

  defp map_label(map) when map_size(map) == 0, do: "empty"

  defp map_label(map),
    do: map |> Enum.sort() |> Enum.map_join(" · ", fn {key, count} -> "#{key} #{count}" end)
end

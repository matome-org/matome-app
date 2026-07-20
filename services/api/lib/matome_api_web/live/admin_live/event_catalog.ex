defmodule MatomeApiWeb.AdminLive.EventCatalog do
  use MatomeApiWeb, :live_view

  import MatomeApiWeb.MatomeComponents
  import MatomeApiWeb.MatomeComposites

  alias MatomeApi.{Admin, Events}
  alias MatomeApiWeb.AdminAuth

  @impl true
  def mount(params, _session, socket) do
    catalog_class = allowed_class(params["event_class"])

    {:ok,
     socket
     |> assign(page_title: "Event catalog", catalog_class: catalog_class)
     |> load_catalogs()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(catalog_class: allowed_class(params["event_class"]))
     |> load_catalogs()}
  end

  def handle_event("update_catalog", params, socket) do
    if recent_otp?(socket) do
      with {:ok, retention_days} <- parse_retention(params["retention_days"]),
           {:ok, _catalog} <-
             Admin.update_event_catalog(
               params["key"],
               %{enabled: params["enabled"] == "true", retention_days: retention_days},
               mutation_opts(socket)
             ) do
        {:noreply,
         socket
         |> put_flash(:info, "Event catalog policy updated.")
         |> load_catalogs()}
      else
        {:error, :forbidden} ->
          {:noreply, redirect(socket, to: "/admin/login")}

        {:error, :recent_otp_required} ->
          reauthenticate(socket)

        {:error, :locked} ->
          {:noreply, put_flash(socket, :error, "Locked policy cannot be changed.")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Event catalog update failed.")}
      end
    else
      reauthenticate(socket)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-catalog">
      <h1 class="admin-catalog__title">Event catalog</h1>
      <p class="admin-catalog__lede">
        Stable collection policy. Locked security and required operational rows cannot be changed.
      </p>

      <nav class="admin-events__views" aria-label="Event views">
        <a href="/admin/events">Events</a>
        <a href="/admin/events/security">Security saved view</a>
      </nav>

      <form phx-change="filter" class="admin-catalog__filters">
        <.select
          name="event_class"
          label="Class"
          value={@catalog_class || ""}
          options={[{"All classes", ""}, {"Security", "security"}, {"Operational", "operational"}, {"Product", "product"}]}
        />
      </form>

      <.data_table rows={@catalogs} row_id={& &1.key}>
        <:col :let={catalog} label="Key">
          <.table_primary_cell title={catalog.key} summary={catalog.description} />
        </:col>
        <:col :let={catalog} label="Class" width="sync">
          <.status_badge label={catalog.event_class} tone={class_tone(catalog.event_class)} />
        </:col>
        <:col :let={catalog} label="State" width="sync">
          {if catalog.enabled, do: "Enabled", else: "Disabled"}
        </:col>
        <:col :let={catalog} label="Retention" width="when">{catalog.retention_days} days</:col>
        <:col :let={catalog} label="Policy" width="matome">
          <span :if={catalog.locked}>Locked</span>
          <form :if={!catalog.locked} phx-submit="update_catalog" class="admin-catalog__control">
            <input type="hidden" name="key" value={catalog.key} />
            <.select
              name="enabled"
              label="Collection"
              value={to_string(catalog.enabled)}
              options={[{"Enabled", "true"}, {"Disabled", "false"}]}
            />
            <.text_field
              name="retention_days"
              label="Retention days"
              value={to_string(catalog.retention_days)}
              inputmode="numeric"
              required
            />
            <.text_button type="submit">Save</.text_button>
          </form>
        </:col>
      </.data_table>
    </div>
    """
  end

  defp load_catalogs(socket),
    do: assign(socket, catalogs: Events.list_catalog(socket.assigns.catalog_class))

  defp allowed_class(value) when value in ~w(security operational product), do: value
  defp allowed_class(_value), do: nil

  defp parse_retention(value) do
    case Integer.parse(to_string(value || "")) do
      {days, ""} when days > 0 -> {:ok, days}
      _other -> {:error, :invalid_retention}
    end
  end

  defp recent_otp?(socket) do
    AdminAuth.recent_otp?(%{"admin_otp_verified_at" => socket.assigns.otp_verified_at})
  end

  defp mutation_opts(socket) do
    [
      actor: socket.assigns.current_admin,
      otp_verified_at: socket.assigns.otp_verified_at,
      remote_ip: socket.assigns.client_ip
    ]
  end

  defp reauthenticate(socket) do
    {:noreply,
     redirect(socket, to: "/admin/otp?return_to=#{URI.encode_www_form("/admin/event-catalog")}")}
  end

  defp class_tone("security"), do: "warn"
  defp class_tone("operational"), do: "work"
  defp class_tone(_class), do: "default"
end

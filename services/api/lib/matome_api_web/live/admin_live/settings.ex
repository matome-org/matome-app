defmodule MatomeApiWeb.AdminLive.Settings do
  use MatomeApiWeb, :live_view

  alias MatomeApi.{Admin, SystemConfig}
  alias MatomeApiWeb.AdminAuth

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "System settings") |> load_status()}
  end

  @impl true
  def handle_event("toggle_queue", params, socket) do
    with true <- recent_otp?(socket),
         {:ok, revision} <- parse_integer(params["base_revision"]),
         {:ok, paused} <- parse_boolean(params["paused"]),
         desired = put_in(socket.assigns.status.config["desired"], ["queue", "paused"], paused),
         {:ok, _config} <- Admin.update_system_config(desired, revision, mutation_opts(socket)) do
      message = if paused, do: "Oban queue paused.", else: "Oban queue resumed."
      {:noreply, socket |> put_flash(:info, message) |> load_status()}
    else
      false -> reauthenticate(socket)
      {:error, :recent_otp_required} -> reauthenticate(socket)
      {:error, :forbidden} -> {:noreply, redirect(socket, to: "/admin/login")}
      {:error, :stale_revision} -> update_failed(socket, "Policy changed; review and retry.")
      {:error, _reason} -> update_failed(socket, "Queue policy update failed.")
    end
  end

  def handle_event("update_policy", params, socket) do
    with true <- recent_otp?(socket),
         {:ok, revision} <- parse_integer(params["base_revision"]),
         {:ok, desired} <- desired_from_params(params, socket.assigns.status.config["desired"]),
         {:ok, _config} <- Admin.update_system_config(desired, revision, mutation_opts(socket)) do
      {:noreply,
       socket
       |> put_flash(:info, "System policy updated.")
       |> load_status()}
    else
      false -> reauthenticate(socket)
      {:error, :recent_otp_required} -> reauthenticate(socket)
      {:error, :forbidden} -> {:noreply, redirect(socket, to: "/admin/login")}
      {:error, :stale_revision} -> update_failed(socket, "Policy changed; review and retry.")
      {:error, _reason} -> update_failed(socket, "System policy update failed validation.")
    end
  end

  @impl true
  def render(assigns) do
    desired = assigns.status.config["desired"]
    assigns = assign(assigns, :desired, desired)

    ~H"""
    <section class="admin-catalog">
      <h1 class="admin-catalog__title">System settings</h1>
      <p class="admin-catalog__lede">
        Versioned non-secret queue, retry, upload, processing, and client policy.
        Credentials, service tokens, signing material, and network endpoints remain environment-only.
      </p>

      <div class="admin-dashboard__kpis" role="group" aria-label="Configuration status">
        <div class="admin-kpi">
          <span class="admin-kpi__label">Desired revision</span>
          <span class="admin-kpi__value">{@status.config["revision"]}</span>
        </div>
        <div class="admin-kpi">
          <span class="admin-kpi__label">Applied revision</span>
          <span class="admin-kpi__value">{@status.config["applied"]["core_revision"]}</span>
        </div>
        <div class="admin-kpi">
          <span class="admin-kpi__label">Effective Oban state</span>
          <span class="admin-kpi__value">{effective_queue_label(@status.queue)}</span>
        </div>
        <div class="admin-kpi">
          <span class="admin-kpi__label">Restart required</span>
          <span class="admin-kpi__value">{yes_no(@status.queue.restart_required)}</span>
        </div>
      </div>

      <p :if={@status.queue.mismatch} class="notice-banner" role="status">
        Desired and effective queue state differ. The supervised reconciler will retry; restart is
        required only when the local Oban producer is unavailable.
      </p>

      <form phx-submit="toggle_queue" class="admin-catalog__control">
        <input type="hidden" name="base_revision" value={@status.config["revision"]} />
        <input type="hidden" name="paused" value={to_string(!@desired["queue"]["paused"])} />
        <button type="submit" class="text-button">
          {if @desired["queue"]["paused"], do: "Resume AI queue", else: "Pause AI queue"}
        </button>
      </form>

      <form phx-submit="update_policy" class="admin-catalog__filters">
        <input type="hidden" name="base_revision" value={@status.config["revision"]} />

        <fieldset>
          <legend>Queue and client work</legend>
          <.number_input name="max_concurrency" label="Desired Oban concurrency" value={@desired["queue"]["max_concurrency"]} />
          <.number_input name="lease_seconds" label="Client lease seconds" value={@desired["queue"]["lease_seconds"]} />
          <.number_input name="snapshot_interval_seconds" label="Reporting interval seconds" value={@desired["queue"]["snapshot_interval_seconds"]} />
        </fieldset>

        <fieldset>
          <legend>Retry bounds</legend>
          <.number_input name="max_attempts" label="Maximum attempts" value={@desired["retry"]["max_attempts"]} />
          <.number_input name="base_delay_seconds" label="Base delay seconds" value={@desired["retry"]["base_delay_seconds"]} />
          <.number_input name="max_delay_seconds" label="Maximum delay seconds" value={@desired["retry"]["max_delay_seconds"]} />
        </fieldset>

        <fieldset>
          <legend>Upload thresholds</legend>
          <.number_input name="single_max_bytes" label="Single upload maximum bytes" value={@desired["uploads"]["single_max_bytes"]} />
          <.number_input name="multipart_part_bytes" label="Multipart part bytes" value={@desired["uploads"]["multipart_part_bytes"]} />
          <.number_input name="max_bytes" label="Application upload maximum bytes" value={@desired["uploads"]["max_bytes"]} />
        </fieldset>

        <fieldset>
          <legend>Processing and reporting</legend>
          <label>
            Enabled input kinds
            <input type="text" name="enabled_input_kinds" value={Enum.join(@desired["ai"]["enabled_input_kinds"], ",")} required />
          </label>
          <.number_input name="job_timeout_seconds" label="Processing timeout seconds" value={@desired["ai"]["job_timeout_seconds"]} />
          <label>
            Minimum wire version
            <input type="text" name="minimum_wire_version" value={@desired["clients"]["minimum_wire_version"]} required />
          </label>
          <.number_input name="poll_interval_seconds" label="Client poll interval seconds" value={@desired["clients"]["poll_interval_seconds"]} />
        </fieldset>

        <button type="submit" class="text-button">Save policy</button>
      </form>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp number_input(assigns) do
    ~H"""
    <label>
      {@label}
      <input type="number" name={@name} value={@value} inputmode="numeric" required />
    </label>
    """
  end

  defp desired_from_params(params, current) do
    integer_fields = ~w(
      max_concurrency lease_seconds snapshot_interval_seconds
      max_attempts base_delay_seconds max_delay_seconds
      single_max_bytes multipart_part_bytes max_bytes
      job_timeout_seconds poll_interval_seconds
    )

    with {:ok, values} <- parse_integers(params, integer_fields) do
      kinds =
        params["enabled_input_kinds"]
        |> to_string()
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)

      {:ok,
       %{
         "queue" => %{
           "paused" => current["queue"]["paused"],
           "max_concurrency" => values["max_concurrency"],
           "lease_seconds" => values["lease_seconds"],
           "snapshot_interval_seconds" => values["snapshot_interval_seconds"]
         },
         "retry" => %{
           "max_attempts" => values["max_attempts"],
           "base_delay_seconds" => values["base_delay_seconds"],
           "max_delay_seconds" => values["max_delay_seconds"]
         },
         "uploads" => %{
           "single_max_bytes" => values["single_max_bytes"],
           "multipart_part_bytes" => values["multipart_part_bytes"],
           "max_bytes" => values["max_bytes"]
         },
         "ai" => %{
           "enabled_input_kinds" => kinds,
           "job_timeout_seconds" => values["job_timeout_seconds"]
         },
         "clients" => %{
           "minimum_wire_version" => String.trim(to_string(params["minimum_wire_version"])),
           "poll_interval_seconds" => values["poll_interval_seconds"]
         }
       }}
    end
  end

  defp parse_integers(params, fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, values} ->
      case parse_integer(params[field]) do
        {:ok, value} -> {:cont, {:ok, Map.put(values, field, value)}}
        error -> {:halt, error}
      end
    end)
  end

  defp parse_integer(value) do
    case Integer.parse(to_string(value || "")) do
      {integer, ""} -> {:ok, integer}
      _other -> {:error, :invalid_integer}
    end
  end

  defp parse_boolean("true"), do: {:ok, true}
  defp parse_boolean("false"), do: {:ok, false}
  defp parse_boolean(_value), do: {:error, :invalid_boolean}

  defp load_status(socket), do: assign(socket, status: SystemConfig.status())

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

  defp update_failed(socket, message),
    do: {:noreply, socket |> put_flash(:error, message) |> load_status()}

  defp reauthenticate(socket) do
    {:noreply,
     redirect(socket, to: "/admin/otp?return_to=#{URI.encode_www_form("/admin/settings")}")}
  end

  defp effective_queue_label(%{effective: nil}), do: "Unavailable"

  defp effective_queue_label(%{effective: effective}) do
    state = if effective["paused"], do: "paused", else: "running"
    "#{state} · #{effective["max_concurrency"]}"
  end

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"
end

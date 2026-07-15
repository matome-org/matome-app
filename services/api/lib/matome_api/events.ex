defmodule MatomeApi.Events do
  @moduledoc """
  Canonical event collection, catalog policy, retention, and pagination.

  Security writes are fail-closed through `write_security!/2`. Operational and
  product callers use `write_optional/2`; disabled or malformed optional events
  never block the product operation that attempted to report them.
  """

  import Ecto.Query
  require Logger

  alias MatomeApi.Events.{Event, EventCatalog}
  alias MatomeApi.Repo

  @max_page_size 100
  @default_page_size 50

  @detail_keys %{
    "security.event_catalog.changed.v1" => ~w(changed_fields),
    "security.admin.login_otp_requested.v1" => [],
    "security.admin.login.v1" => ~w(method result via),
    "security.admin.login_failed.v1" => ~w(method reason result),
    "security.admin.logout.v1" => [],
    "security.admin.reauth.v1" => ~w(method result),
    "security.admin.session_revoked.v1" => [],
    "security.admin.session_revoked.v2" => ~w(before after),
    "security.admin.space_updated.v1" => ~w(changed_keys),
    "security.admin.space_updated.v2" => ~w(changed_keys before after),
    "security.admin.space_member_added.v1" => ~w(workspace_id user_id role),
    "security.admin.space_member_added.v2" => ~w(workspace_id user_id role before after),
    "security.admin.space_member_revoked.v1" => ~w(workspace_id user_id),
    "security.admin.space_member_revoked.v2" => ~w(workspace_id user_id before after),
    "security.admin.space_lifecycle.v1" => ~w(to_status),
    "security.admin.space_lifecycle.v2" => ~w(before after),
    "security.admin.sensitive_read.v1" => ~w(resource result),
    "security.event_catalog.changed.v2" => ~w(changed_fields before after result),
    "security.admin_auth_verified.v1" => ~w(method result),
    "security.admin_config_changed.v1" => ~w(revision changed_keys result),
    "operational.work_transition.v1" =>
      ~w(operation input_kind from_state to_state attempt duration_ms error_code),
    "operational.upload_completed.v1" =>
      ~w(mode byte_size part_count duration_ms result error_code),
    "operational.processing_completed.v1" =>
      ~w(input_kind output_types duration_ms attempt result error_code),
    "product.capture_completed.v1" => ~w(input_kind duration_bucket size_bucket platform result),
    "product.local_space_aggregate.v1" => ~w(period item_count_bucket byte_size_bucket platform),
    "product.matome_added.v1" => [],
    "product.matome_removed.v1" => [],
    "product.matome_archived.v1" => []
  }

  @admin_action_keys %{
    "admin.login_otp_requested" => "security.admin.login_otp_requested.v1",
    "admin.login" => "security.admin.login.v1",
    "admin.login_failed" => "security.admin.login_failed.v1",
    "admin.logout" => "security.admin.logout.v1",
    "admin.reauth" => "security.admin.reauth.v1",
    "admin.session_revoked" => "security.admin.session_revoked.v2",
    "admin.space_updated" => "security.admin.space_updated.v2",
    "admin.space_member_added" => "security.admin.space_member_added.v2",
    "admin.space_member_revoked" => "security.admin.space_member_revoked.v2",
    "admin.space_lifecycle" => "security.admin.space_lifecycle.v2",
    "admin.sensitive_read" => "security.admin.sensitive_read.v1"
  }

  def detail_keys(key), do: Map.fetch(@detail_keys, key)
  def admin_event_key(action), do: Map.fetch(@admin_action_keys, action)

  @doc "Writes a mandatory security event or raises without allowing the caller to continue."
  def write_security!(key, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    case Repo.get(EventCatalog, key) do
      %EventCatalog{event_class: "security", enabled: true} ->
        %Event{event_key: key}
        |> Event.changeset(attrs)
        |> Repo.insert!()

      %EventCatalog{event_class: "security"} ->
        raise "security event is disabled: #{key}"

      %EventCatalog{} ->
        raise ArgumentError, "event is not security-class: #{key}"

      nil ->
        raise ArgumentError, "unknown security event: #{key}"
    end
  end

  @doc "Adds a mandatory event insert to an existing transaction."
  def put_security(multi, name, key, attrs_or_fun)

  def put_security(%Ecto.Multi{} = multi, name, key, attrs)
      when is_map(attrs) or is_list(attrs) do
    multi
    |> require_security_catalog(name, key)
    |> Ecto.Multi.insert(name, security_changeset(key, attrs))
  end

  def put_security(%Ecto.Multi{} = multi, name, key, attrs_fun) when is_function(attrs_fun, 1) do
    multi
    |> require_security_catalog(name, key)
    |> Ecto.Multi.insert(name, fn changes ->
      key
      |> security_changeset(attrs_fun.(changes))
    end)
  end

  defp require_security_catalog(multi, name, key) do
    Ecto.Multi.run(multi, {name, :security_policy}, fn repo, _changes ->
      case repo.get(EventCatalog, key) do
        %EventCatalog{event_class: "security", enabled: true} = catalog -> {:ok, catalog}
        _catalog -> {:error, :security_event_required}
      end
    end)
  end

  defp security_changeset(key, attrs) do
    %Event{event_key: key}
    |> Event.changeset(normalize_attrs(attrs))
  end

  @doc "Best-effort write for operational and product events. Never raises."
  def write_optional(key, attrs \\ %{}) do
    case Repo.get(EventCatalog, key) do
      nil ->
        {:error, :unknown_event}

      %EventCatalog{event_class: "security"} ->
        {:error, :security_requires_fail_closed}

      %EventCatalog{enabled: false} ->
        {:ok, :disabled}

      %EventCatalog{} ->
        changeset = Event.changeset(%Event{event_key: key}, normalize_attrs(attrs))

        if changeset.valid? do
          case Repo.insert(changeset) do
            {:ok, event} -> {:ok, event}
            {:error, _changeset} -> {:error, :write_failed}
          end
        else
          {:error, :invalid_event}
        end
    end
  rescue
    exception ->
      Logger.warning("optional event write dropped",
        event_key: key,
        reason: exception.__struct__
      )

      {:error, :write_failed}
  end

  @doc "Accepts an opted-in product event with identity derived by Core."
  def write_product(key, payload, attrs)
      when is_binary(key) and is_map(payload) and is_map(attrs) do
    case Repo.get(EventCatalog, key) do
      %EventCatalog{event_class: "product", locked: false} ->
        attrs
        |> Map.put(:details, payload)
        |> then(&write_optional(key, &1))

      _catalog ->
        {:error, :event_not_allowed}
    end
  end

  def write_product(_key, _payload, _attrs), do: {:error, :invalid_event}

  @doc "Lists catalog policy in stable key order, optionally filtered by class."
  def list_catalog(event_class \\ nil) do
    EventCatalog
    |> maybe_filter_catalog_class(event_class)
    |> order_by([catalog], asc: catalog.key)
    |> Repo.all()
  end

  @doc "Deletes only rows whose snapshotted retention deadline has passed."
  def prune_expired!(cutoff \\ DateTime.utc_now()) do
    %{rows: [[count]]} = Repo.query!("SELECT prune_expired_events($1)", [cutoff])
    count
  end

  @doc "Lists immutable events newest-first using an opaque `(occurred_at, id)` cursor."
  def list_events(opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_page_size) |> normalize_limit()

    query =
      from(e in Event, order_by: [desc: e.occurred_at, desc: e.id])
      |> filter(:event_key, Keyword.get(opts, :event_key))
      |> filter(:event_class, Keyword.get(opts, :event_class))
      |> filter(:actor_id, Keyword.get(opts, :actor_id))
      |> filter(:actor_email, Keyword.get(opts, :actor_email))
      |> filter(:owner_id, Keyword.get(opts, :owner_id))
      |> filter(:subject_type, Keyword.get(opts, :subject_type))
      |> filter(:subject_id, Keyword.get(opts, :subject_id))
      |> filter(:device_id, Keyword.get(opts, :device_id))
      |> filter(:run_id, Keyword.get(opts, :run_id))
      |> filter(:correlation_id, Keyword.get(opts, :correlation_id))
      |> filter(:severity, Keyword.get(opts, :severity))
      |> filter_since(Keyword.get(opts, :since))
      |> filter_until(Keyword.get(opts, :until))
      |> filter_after(Keyword.get(opts, :after))
      |> limit(^(limit + 1))

    rows = Repo.all(query)
    entries = Enum.take(rows, limit)
    next_cursor = if length(rows) > limit, do: entries |> List.last() |> encode_cursor()

    %{entries: entries, next_cursor: next_cursor}
  end

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)

  defp normalize_limit(limit) when is_integer(limit), do: limit |> max(1) |> min(@max_page_size)
  defp normalize_limit(_limit), do: @default_page_size

  defp filter(query, _field, nil), do: query
  defp filter(query, field, value), do: where(query, [e], field(e, ^field) == ^value)

  defp filter_since(query, nil), do: query
  defp filter_since(query, since), do: where(query, [e], e.occurred_at >= ^since)

  defp filter_until(query, nil), do: query
  defp filter_until(query, until), do: where(query, [e], e.occurred_at < ^until)

  defp filter_after(query, nil), do: query

  defp filter_after(query, cursor) do
    {occurred_at, id} = decode_cursor!(cursor)

    where(
      query,
      [e],
      e.occurred_at < ^occurred_at or (e.occurred_at == ^occurred_at and e.id < ^id)
    )
  end

  defp encode_cursor(%Event{occurred_at: occurred_at, id: id}) do
    "#{DateTime.to_unix(occurred_at, :microsecond)}:#{id}"
    |> Base.url_encode64(padding: false)
  end

  defp decode_cursor!(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         [micros, id] <- String.split(decoded, ":", parts: 2),
         {micros, ""} <- Integer.parse(micros),
         {id, ""} <- Integer.parse(id),
         {:ok, occurred_at} <- DateTime.from_unix(micros, :microsecond) do
      {occurred_at, id}
    else
      _error -> raise ArgumentError, "invalid event cursor"
    end
  end

  defp decode_cursor!(_cursor), do: raise(ArgumentError, "invalid event cursor")

  defp maybe_filter_catalog_class(query, nil), do: query

  defp maybe_filter_catalog_class(query, event_class)
       when event_class in ~w(security operational product),
       do: where(query, [catalog], catalog.event_class == ^event_class)

  defp maybe_filter_catalog_class(query, _event_class), do: query
end

defmodule MatomeApi.SystemConfig do
  @moduledoc "Persistence and optimistic updates for the global non-secret policy."

  import Ecto.Query

  alias Ecto.Multi
  alias MatomeApi.Events
  alias MatomeApi.Repo
  alias MatomeApi.SystemConfig.Config
  alias MatomeApi.SystemConfig.{ObanQueueAdapter, QueueAdapter}

  @key "global"

  def get!, do: Repo.get!(Config, @key)
  def current_revision, do: get!().document["revision"]
  def desired, do: get!().document["desired"]
  def snapshot, do: get!().document

  def status(adapter \\ ObanQueueAdapter) do
    document = get!().document
    desired_queue = document["desired"]["queue"] |> Map.take(["paused", "max_concurrency"])

    effective_queue =
      case QueueAdapter.status(adapter) do
        {:ok, effective} -> effective
        {:error, _reason} -> nil
      end

    applied_revision = document["applied"]["core_revision"]

    %{
      config: document,
      queue: %{
        desired: desired_queue,
        effective: effective_queue,
        mismatch:
          is_nil(effective_queue) or effective_queue != desired_queue or
            applied_revision != document["revision"],
        restart_required: is_nil(effective_queue)
      }
    }
  end

  def update_desired(desired, base_revision, context)
      when is_map(desired) and is_integer(base_revision) and is_map(context) do
    Multi.new()
    |> Multi.run(:config, fn repo, _changes ->
      config = repo.one!(from c in Config, where: c.key == @key, lock: "FOR UPDATE")

      if config.document["revision"] == base_revision,
        do: {:ok, config},
        else: {:error, :stale_revision}
    end)
    |> Multi.run(:updated, fn repo, %{config: config} ->
      revision = config.document["revision"] + 1

      document =
        config.document
        |> Map.put("revision", revision)
        |> Map.put("desired", desired)

      config
      |> Config.changeset(%{document: document})
      |> repo.update()
    end)
    |> Events.put_security(:event, "security.admin_config_changed.v2", fn %{
                                                                            config: before,
                                                                            updated: after_config
                                                                          } ->
      before_desired = before.document["desired"]
      after_desired = after_config.document["desired"]

      changed_keys =
        after_desired
        |> Map.keys()
        |> Enum.filter(&(Map.get(before_desired, &1) != Map.get(after_desired, &1)))
        |> Enum.sort()

      %{
        actor_email: context.actor.email,
        remote_ip: context.remote_ip,
        subject_type: "system_config",
        subject_id: @key,
        details: %{
          revision: after_config.document["revision"],
          changed_keys: changed_keys,
          before: Jason.encode!(before_desired),
          after: Jason.encode!(after_desired),
          result: "updated"
        }
      }
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated: updated}} -> {:ok, updated}
      {:error, :event, changeset, _changes} -> {:error, {:audit_failed, changeset}}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def mark_applied(revision, applied_at \\ DateTime.utc_now()) when is_integer(revision) do
    Repo.transaction(fn ->
      config = Repo.one!(from c in Config, where: c.key == @key, lock: "FOR UPDATE")

      if config.document["revision"] == revision do
        applied = %{
          "core_revision" => revision,
          "core_applied_at" => applied_at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
        }

        config
        |> Config.changeset(%{document: Map.put(config.document, "applied", applied)})
        |> Repo.update!()
      else
        Repo.rollback(:stale_revision)
      end
    end)
  end
end

defmodule MatomeApi.Content.SpaceLifecycleJob do
  @moduledoc """
  Oban worker for workspace (Space) lifecycle transitions.

  Allowed transitions:
  - `active` → `suspended` | `archived`
  - `suspended` → `active` | `archived`
  - `archived` → `deleted` (grace / hard-delete marker)
  - `deleted` is terminal for this worker (storage reap is a later concern)
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query

  alias MatomeApi.Content.Workspace
  alias MatomeApi.Repo

  @allowed %{
    "active" => ~w(suspended archived),
    "suspended" => ~w(active archived),
    "archived" => ~w(deleted)
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"workspace_id" => workspace_id, "to_status" => to_status}}) do
    transition(workspace_id, to_status)
  end

  def perform(%Oban.Job{}), do: {:discard, :invalid_args}

  @doc "Enqueue a lifecycle transition."
  def enqueue(workspace_id, to_status) when is_binary(to_status) do
    %{workspace_id: workspace_id, to_status: to_status}
    |> new()
    |> Oban.insert()
  end

  @doc "Apply a lifecycle transition synchronously (also used by the worker)."
  def transition(workspace_id, to_status) when is_binary(to_status) do
    case Repo.get(Workspace, workspace_id) do
      nil ->
        {:discard, :missing_workspace}

      %Workspace{} = workspace ->
        case transition_changeset(workspace, to_status) do
          {:ok, changeset} ->
            case Repo.update(changeset) do
              {:ok, _} -> :ok
              {:error, changeset} -> {:error, changeset}
            end

          {:error, reason} ->
            {:discard, reason}
        end
    end
  end

  @doc false
  def transition_changeset(%Workspace{status: from} = workspace, to_status)
      when is_binary(to_status) do
    if to_status in Map.get(@allowed, from, []) do
      {:ok, Workspace.admin_changeset(workspace, %{status: to_status})}
    else
      {:error, {:invalid_transition, from, to_status}}
    end
  end

  @doc """
  Suspend spaces whose `expires_at` has passed while still `active`.
  Intended for a cron/Oban plugin; callable from tests.
  """
  def expire_due(now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    from(w in Workspace,
      where: w.status == "active",
      where: not is_nil(w.expires_at),
      where: w.expires_at <= ^now,
      select: w.id
    )
    |> Repo.all()
    |> Enum.map(fn id -> enqueue(id, "suspended") end)
  end
end
